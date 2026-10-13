"""Freeze a licensed, speaker-disjoint corpus before any model inference.

The training split is only a source of evaluation audio: this tool does not
train a model. Pretraining overlap is unknown. Audio/reference text stays in
ignored build/, and no reference words are passed to an inference engine.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import wave
import urllib.request
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import pyarrow as pa
import pyarrow.parquet as pq

REVISION = '737e9800ae31be9932ba8464c80366559bd28424'
SOURCE = f'https://huggingface.co/datasets/CAiRE/ASCEND/tree/{REVISION}'
PARTS = [
    ('train-00000.parquet', '3d66ba76f324e0711b779cfb01ee4e772a24a929e1d77a2063cde0506f75976f'),
    ('train-00001.parquet', '569f84f771c3637ca8535bd35e10e62feed2c240833534711909a9c04f51e589'),
    ('train-00002.parquet', 'aa76b7ef4a74ff111fd1d2573d0b69e6b6f901df6054618d8e5658a7a394523e'),
]
EXCLUDED = {3, 7, 12, 17, 20}

def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def download_part(source, part, mirror=False):
    filename, expected = PARTS[part]
    destination = source / filename
    if destination.exists():
        assert digest(destination) == expected, f'Unexpected cached corpus: {filename}'
        return
    temporary = source / (filename + '.part')
    host = 'hf-mirror.com' if mirror else 'huggingface.co'
    url = f'https://{host}/datasets/CAiRE/ASCEND/resolve/{REVISION}/main/train-{part:05d}-of-00003.parquet'
    for attempt in range(4):
        offset = temporary.stat().st_size if temporary.exists() else 0
        request = urllib.request.Request(url, headers={'Range': f'bytes={offset}-'} if offset else {})
        try:
            # Use the host's configured proxy, normal HTTPS validation and
            # validated Range responses; never mix a full response with a tail.
            with urllib.request.urlopen(request, timeout=60) as response:
                append = bool(offset and response.status == 206)
                if append:
                    assert response.headers.get('Content-Range', '').startswith(f'bytes {offset}-'), 'Unexpected resume offset'
                with temporary.open('ab' if append else 'wb') as output:
                    while block := response.read(1024 * 1024):
                        output.write(block)
            assert digest(temporary) == expected, f'Download hash mismatch: {filename}'
            break
        except (OSError, TimeoutError) as error:
            if attempt == 3:
                raise
            print(f'Shard {part + 1}: retrying transfer ({type(error).__name__})', flush=True)
            time.sleep(2 * (attempt + 1))
    temporary.replace(destination)
    print(f'Verified source shard {part + 1}/3', flush=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-directory', required=True)
    parser.add_argument('--output', default='build/corpus/ascend-unseen-speakers')
    parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg'))
    parser.add_argument('--download', action='store_true', help='Download fixed public source shards through the configured host network')
    parser.add_argument('--mirror', action='store_true', help='Use the same pinned bytes via hf-mirror.com; all source SHA-256 checks still required')
    args = parser.parse_args()
    assert args.ffmpeg, 'FFmpeg is required for genuine audio normalization'
    output = Path(args.output)
    assert not output.exists() or not any(output.iterdir()), 'Choose a new empty corpus directory'
    source = Path(args.source_directory)
    if args.download:
        source.mkdir(parents=True, exist_ok=True)
        with ThreadPoolExecutor(max_workers=3) as pool:
            list(pool.map(lambda part: download_part(source, part, args.mirror), range(3)))
    rows = []
    for part, (filename, expected) in enumerate(PARTS):
        path = source / filename
        assert digest(path) == expected, f'Unexpected corpus bytes: {filename}'
        metadata = pq.read_table(path, columns=['id', 'original_speaker_id', 'duration', 'language', 'transcription']).to_pylist()
        rows.extend(dict(row, _part=part, _row=index) for index, row in enumerate(metadata))
    speakers = sorted({row['original_speaker_id'] for row in rows} - EXCLUDED)[:10]
    assert len(speakers) == 10, 'Ten previously unused speakers required'
    selected = []
    for language in ('zh', 'en', 'mixed'):
        queues = [[row for row in rows if row['original_speaker_id'] == speaker
                   and row['language'] == language and row['duration'] >= 2] for speaker in speakers]
        group = []
        index = 0
        while len(group) < 100:
            available = [queue[index] for queue in queues if index < len(queue)]
            if not available:
                break
            group.extend(available[:100 - len(group)])
            index += 1
        assert len(group) == 100, f'Insufficient {language} clips'
        assert len({row['original_speaker_id'] for row in group}) == 10, f'Insufficient {language} speaker coverage'
        selected.extend(group)
    assert len({row['id'] for row in selected}) == 300
    # Read one shard at a time; materialize only the selected audio bytes.
    audio = {}
    for part, (filename, _) in enumerate(PARTS):
        selected_rows = [row for row in selected if row['_part'] == part]
        if not selected_rows:
            continue
        indices = [row['_row'] for row in selected_rows]
        table = pq.read_table(source / filename, columns=['audio'])
        chosen = table.take(pa.array(indices)).to_pylist()
        for row, value in zip(selected_rows, chosen, strict=True):
            audio[row['id']] = value['audio']['bytes']
        del table, chosen
    output.mkdir(parents=True, exist_ok=True)
    clips = []
    for row in selected:
        name = 'ascend-' + row['id']
        original = output / (name + '.source.wav')
        original.write_bytes(audio.pop(row['id']))
        normalized = output / (name + '.wav')
        subprocess.run([args.ffmpeg, '-y', '-loglevel', 'error', '-i', str(original),
                        '-ac', '1', '-ar', '16000', '-c:a', 'pcm_s16le', str(normalized)], check=True)
        with wave.open(str(normalized)) as wav:
            assert wav.getframerate() == 16000 and wav.getnchannels() == 1 and wav.getsampwidth() == 2
            duration = (wav.getnframes() + 15) // 16
        clips.append({'id': name, 'file': normalized.name, 'kind': 'licensed_human',
                      'source': SOURCE, 'license': 'CC-BY-SA-4.0', 'language': 'auto',
                      'prompt': '', 'datasetLanguage': row['language'],
                      'speakerId': row['original_speaker_id'], 'durationMs': duration,
                      'sha256': digest(normalized), 'text': row['transcription']})
    hashes = {clip['sha256'] for clip in clips}
    assert len(hashes) == 300, 'Duplicate audio in the new corpus'
    root = Path(__file__).resolve().parents[1]
    previous = {}
    for directory in ('ascend-expanded', 'ascend-holdout'):
        path = root / 'build/corpus' / directory / 'manifest.json'
        assert path.exists(), 'Prior regression manifests required for disjointness verification'
        prior = json.loads(path.read_text(encoding='utf-8'))
        assert not hashes & {clip['sha256'] for clip in prior['clips']}, 'Prior audio reused'
        assert not set(speakers) & {clip['speakerId'] for clip in prior['clips']}, 'Prior speaker reused'
        previous[directory] = digest(path)
    manifest = {'sourceRevision': REVISION, 'source': SOURCE,
                'attribution': 'HKUST CAiRE; Lovenia et al., ASCEND (LREC 2022)',
                'license': 'CC-BY-SA-4.0', 'split': 'train (used only for evaluation)',
                'selection': 'Before inference: first ten sorted numeric speaker IDs excluding all five previously studied speakers; first 100 clips per language with duration >=2 s, round-robin preserving shard/row order; no selection by transcript or model result',
                'excludedSpeakers': sorted(EXCLUDED), 'selectedSpeakers': speakers,
                'sourceHashes': dict(PARTS), 'selectionFrozenBeforeInference': True,
                'priorManifestsSha256': previous, 'audioAndSpeakersDisjointVerified': True,
                'scope': 'Disjoint from prior app tuning speakers. Unknown model pretraining overlap; short conversational clips do not cover long audio, noise, power or commercial acceptance alone.',
                'clips': clips}
    destination = output / 'manifest.json'
    destination.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Frozen 300 real clips / ten speakers, manifest SHA-256 {digest(destination)}')

if __name__ == '__main__':
    main()
