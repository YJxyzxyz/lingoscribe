"""Research-only real SenseVoice comparison against the same licensed corpus.

This does not integrate the alternative model into the mobile product. Its
custom model license needs a separate distribution review before shipping.
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

parser = argparse.ArgumentParser()
parser.add_argument('--model', required=True)
parser.add_argument('--tokens', required=True)
parser.add_argument('--manifest', required=True)
parser.add_argument('--audio-root', required=True)
parser.add_argument('--report', default='build/sensevoice-research-evaluation.json')
parser.add_argument('--include-text', action='store_true')
args = parser.parse_args()
assert digest(args.model) == 'c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51'
assert digest(args.tokens) == 'f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc'
corpus = json.loads(Path(args.manifest).read_text(encoding='utf-8'))
rows = []
for clip in corpus['clips']:
    assert clip['kind'] == 'licensed_human' and clip.get('license') and clip.get('source')
    audio = Path(args.audio_root) / clip['file']
    assert digest(audio) == clip['sha256']
    with wave.open(str(audio)) as wav:
        assert wav.getnchannels() == 1 and wav.getsampwidth() == 2 and wav.getframerate() == 16000
        samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype='<i2').astype(np.float32) / 32768
    started = time.perf_counter()
    # Reload for each clip to match the production Whisper job's model lifetime.
    recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
        model=args.model, tokens=args.tokens, num_threads=4, language='auto', use_itn=False, provider='cpu', debug=False)
    stream = recognizer.create_stream()
    stream.accept_waveform(16000, samples)
    recognizer.decode_stream(stream)
    elapsed = time.perf_counter() - started
    hypothesis = stream.result.text
    cn, en, _ = tokens(clip['text'])
    actual_cn, actual_en, _ = tokens(hypothesis)
    row = {'id': clip['id'], 'kind': clip['kind'], 'source': clip['source'], 'license': clip['license'],
           'datasetLanguage': clip['datasetLanguage'], 'speakerId': clip['speakerId'], 'audioSha256': digest(audio),
           'durationMs': round(len(samples) / 16), 'elapsedSeconds': round(elapsed, 3),
           'chineseReferenceChars': len(cn), 'chineseEditDistance': distance(cn, actual_cn),
           'englishReferenceWords': len(en), 'englishEditDistance': distance(en, actual_en)}
    if args.include_text:
        row.update(reference=clip['text'], hypothesis=hypothesis)
    rows.append(row)
    del stream, recognizer
groups = {}
for group in ('zh', 'en', 'mixed'):
    selected = [row for row in rows if row['datasetLanguage'] == group]
    cn = sum(row['chineseReferenceChars'] for row in selected)
    en = sum(row['englishReferenceWords'] for row in selected)
    cn_errors = sum(row['chineseEditDistance'] for row in selected)
    en_errors = sum(row['englishEditDistance'] for row in selected)
    duration = sum(row['durationMs'] for row in selected) / 1000
    groups[group] = {'clips': len(selected), 'chineseReferenceChars': cn, 'chineseEditDistance': cn_errors,
                     'chineseCER': cn_errors / cn if cn else None, 'englishReferenceWords': en,
                     'englishEditDistance': en_errors, 'englishWER': en_errors / en if en else None,
                     'durationSeconds': round(duration, 3),
                     'rtf': round(sum(row['elapsedSeconds'] for row in selected) / duration, 3)}
report = {'engine': 'sherpa-onnx ' + sherpa_onnx.__version__, 'platform': platform.system(),
          'model': 'SenseVoiceSmall 2024-07-17 int8 ONNX', 'modelSha256': digest(args.model),
          'tokensSha256': digest(args.tokens), 'sourceRevision': '2365baeacb507f821a0c8120fcee3d484dba7a07',
          'modelAttribution': 'Alibaba / FunAudioLLM SenseVoiceSmall; ONNX export by k2-fsa / Fangjun Kuang',
          'modelLicense': 'https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE',
          'manifestSha256': digest(args.manifest), 'corpusAttribution': corpus['attribution'],
          'normalization': 'Same NFKC/Han-CER/Latin-WER rules as evaluate_transcription.py; no script conversion',
          'aggregates': groups, 'clips': rows,
          'scope': 'Research-only public corpus evaluation; no mobile integration or commercial distribution clearance; tiny subset is not representative accuracy or phone performance.'}
destination = Path(args.report)
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Real SenseVoice research results: {destination}')
