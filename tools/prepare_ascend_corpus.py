"""Extract a predetermined, licensed human-speech regression subset locally.

Download the pinned public test Parquet separately. No audio is put in the app.
Requires pyarrow and FFmpeg on the development host only.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
import pyarrow.parquet as pq

REVISION = '737e9800ae31be9932ba8464c80366559bd28424'
SHA = 'a4c81d2b5ed6124f052089a695972808c16e0ce0c365ec9773c5d1a8fcf043a7'
SOURCE = f'https://huggingface.co/datasets/CAiRE/ASCEND/tree/{REVISION}'
parser = argparse.ArgumentParser()
parser.add_argument('parquet')
parser.add_argument('--output', default='build/corpus/ascend')
parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg'))
args = parser.parse_args()
assert args.ffmpeg, 'FFmpeg is required on the test host'
source = Path(args.parquet)
assert hashlib.sha256(source.read_bytes()).hexdigest() == SHA, 'Unexpected corpus bytes'
rows = pq.read_table(source).to_pylist()
speakers = sorted({row['original_speaker_id'] for row in rows})[:3]
selected = []
for speaker in speakers:
    for language in ('zh', 'en', 'mixed'):
        selected.extend([row for row in rows if row['original_speaker_id'] == speaker
                         and row['language'] == language and row['duration'] >= 2][:3])
output = Path(args.output)
output.mkdir(parents=True, exist_ok=True)
clips = []
for row in selected:
    name = 'ascend-' + row['id']
    raw = output / (name + '.source.wav')
    raw.write_bytes(row['audio']['bytes'])
    audio = output / (name + '.wav')
    subprocess.run([args.ffmpeg, '-y', '-loglevel', 'error', '-i', str(raw), '-ac', '1', '-ar', '16000',
                    '-c:a', 'pcm_s16le', str(audio)], check=True)
    clips.append({'id': name, 'file': audio.name, 'kind': 'licensed_human', 'source': SOURCE,
                  'license': 'CC-BY-SA-4.0', 'language': 'auto', 'datasetLanguage': row['language'],
                  'speakerId': row['original_speaker_id'], 'text': row['transcription'],
                  'sha256': hashlib.sha256(audio.read_bytes()).hexdigest(),
                  'sourceAudioSha256': hashlib.sha256(raw.read_bytes()).hexdigest()})
manifest = {'dataset': 'ASCEND', 'attribution': 'HKUST CAiRE; Lovenia et al., ASCEND (LREC 2022)',
            'datasetLicense': 'https://creativecommons.org/licenses/by-sa/4.0/',
            'sourceRevision': REVISION, 'parquetSha256': SHA,
            'selection': 'First up to three numeric speaker IDs in test split; first up to three rows per speaker/language with duration >= 2 seconds; chosen before inference',
            'transform': 'FFmpeg mono PCM16 16 kHz; original reference text retained',
            'scope': 'Small deterministic regression subset, not a representative accuracy benchmark', 'clips': clips}
(output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(output / 'ATTRIBUTION.txt').write_text(manifest['attribution'] + '\n' + SOURCE + '\n' + manifest['datasetLicense'] + '\n' + manifest['transform'] + '\n', encoding='utf-8')
print(f'Prepared {len(clips)} real speech clips from speakers {speakers}; audio/manifest stay in ignored build/.')
