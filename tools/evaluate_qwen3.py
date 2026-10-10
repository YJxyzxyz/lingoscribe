"""Evaluate a pinned Qwen3-ASR export locally; not a mobile feature.

Uses the same licensed corpus and normalization as the Whisper regression.
Model reload time is recorded separately; no mobile speed/memory claim implied.
"""
import argparse
import json
import platform
import time
import wave
from pathlib import Path
import numpy as np
import sherpa_onnx
from evaluate_transcription import digest, distance, tokens

REVISION = '68818b2313fe77bd06f6a7c5068ff3ef59d02b8a'
REPOSITORY = 'csukuangfj2/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25'
HASHES = {
    'conv_frontend.onnx': 'd22dc4423e0940e49884e903d2ea2f7e5567c14fc1aed97e4e26d6b8f208ef9e',
    'encoder.int8.onnx': '60748d3e6744a57c9c91e1b17424a6c2990567e8adceb0783940c03ed98fa9d9',
    'decoder.int8.onnx': '4f6885be5959ae26af3089d38ee7972c5fafbeeb1cf8d5e76eab6d8b61ca5771',
    'tokenizer/merges.txt': '8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5',
    'tokenizer/tokenizer_config.json': '4942d005604266809309cabc9f4e9cb89ce855d59b14681fdc0e1cc62ea26c4c',
    'tokenizer/vocab.json': 'ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910',
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model-directory', required=True)
    parser.add_argument('--manifest', required=True)
    parser.add_argument('--audio-root', required=True)
    parser.add_argument('--report', default='build/qwen3-research-evaluation.json')
    parser.add_argument('--include-text', action='store_true')
    args = parser.parse_args()
    model = Path(args.model_directory)
    for name, expected in HASHES.items():
        if digest(model / name) != expected:
            raise ValueError(f'Unexpected model bytes: {name}')
    corpus = json.loads(Path(args.manifest).read_text(encoding='utf-8'))
    assert corpus['clips'], 'Reference clips are required'
    rows = []
    for index, clip in enumerate(corpus['clips']):
        assert clip['kind'] == 'licensed_human' and clip.get('license') and clip.get('source')
        audio = Path(args.audio_root) / clip['file']
        assert digest(audio) == clip['sha256']
        with wave.open(str(audio)) as wav:
            assert wav.getnchannels() == 1 and wav.getsampwidth() == 2 and wav.getframerate() == 16000
            samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype='<i2').astype(np.float32) / 32768
        started = time.perf_counter()
        recognizer = sherpa_onnx.OfflineRecognizer.from_qwen3_asr(
            conv_frontend=str(model / 'conv_frontend.onnx'), encoder=str(model / 'encoder.int8.onnx'),
            decoder=str(model / 'decoder.int8.onnx'), tokenizer=str(model / 'tokenizer'),
            num_threads=4, max_total_len=512, max_new_tokens=128, provider='cpu', debug=False)
        loaded = time.perf_counter()
        stream = recognizer.create_stream()
        stream.accept_waveform(16000, samples)
        recognizer.decode_stream(stream)
        elapsed = time.perf_counter() - started
        hypothesis = stream.result.text
        cn, en, _ = tokens(clip['text'])
        actual_cn, actual_en, _ = tokens(hypothesis)
        row = {'id': clip['id'], 'kind': clip['kind'], 'source': clip['source'], 'license': clip['license'],
               'datasetLanguage': clip['datasetLanguage'], 'speakerId': clip['speakerId'],
               'audioSha256': digest(audio), 'durationMs': round(len(samples) / 16),
               'elapsedSeconds': round(elapsed, 3), 'loadSeconds': round(loaded - started, 3),
               'inferenceSeconds': round(elapsed - (loaded - started), 3),
               'chineseReferenceChars': len(cn), 'chineseEditDistance': distance(cn, actual_cn),
               'englishReferenceWords': len(en), 'englishEditDistance': distance(en, actual_en)}
        if args.include_text:
            row.update(reference=clip['text'], hypothesis=hypothesis)
        rows.append(row)
        del stream, recognizer
        print(f'Completed {index + 1}/{len(corpus["clips"])}', flush=True)
    groups = {}
    for group in sorted({row['datasetLanguage'] for row in rows}):
        selected = [row for row in rows if row['datasetLanguage'] == group]
        cn = sum(row['chineseReferenceChars'] for row in selected)
        en = sum(row['englishReferenceWords'] for row in selected)
        duration = sum(row['durationMs'] for row in selected) / 1000
        groups[group] = {
            'clips': len(selected), 'durationSeconds': round(duration, 3),
            'chineseReferenceChars': cn,
            'chineseCER': sum(row['chineseEditDistance'] for row in selected) / cn if cn else None,
            'englishReferenceWords': en,
            'englishWER': sum(row['englishEditDistance'] for row in selected) / en if en else None,
            'rtfIncludingLoad': round(sum(row['elapsedSeconds'] for row in selected) / duration, 3),
            'rtfInferenceOnly': round(sum(row['inferenceSeconds'] for row in selected) / duration, 3),
        }
    report = {
        'engine': 'sherpa-onnx ' + sherpa_onnx.__version__, 'platform': platform.system(),
        'model': 'Qwen3-ASR 0.6B int8 ONNX 2026-03-25', 'modelHashes': HASHES,
        'source': f'https://huggingface.co/{REPOSITORY}/tree/{REVISION}',
        'modelAttribution': 'Alibaba Qwen; ONNX export by Wasser1462 / zengshuishui, hosted by Fangjun Kuang',
        'upstreamModelCard': 'https://huggingface.co/Qwen/Qwen3-ASR-0.6B',
        'manifestSha256': digest(args.manifest), 'corpusAttribution': corpus['attribution'],
        'corpusSelection': corpus.get('selection'),
        'normalization': 'Same NFKC/Han-CER/Latin-WER rules as evaluate_transcription.py; no script conversion',
        'settings': {'threads': 4, 'provider': 'cpu', 'maxTotalLen': 512, 'maxNewTokens': 128,
                     'modelLifetime': 'Reload for each clip; load and inference measured separately'},
        'aggregates': groups, 'clips': rows,
        'scope': 'Desktop research, not mobile integration, distribution clearance, representative accuracy or phone performance.',
    }
    destination = Path(args.report)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Real Qwen3 research results: {destination}')


if __name__ == '__main__':
    main()
