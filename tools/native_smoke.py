"""Exercise the real native engine with licensed/local audio. No inference mocks."""
import argparse
import ctypes
import hashlib
import json
import os
import pathlib
import tempfile
import time
import wave

parser = argparse.ArgumentParser()
parser.add_argument('--library', required=True)
parser.add_argument('--model', required=True)
parser.add_argument('--audio', required=True)
parser.add_argument('--report')
parser.add_argument('--language', default='auto')
parser.add_argument('--prompt', default='')
parser.add_argument('--fixture-kind', default='upstream', choices=['upstream', 'synthetic', 'user', 'emulator'])
parser.add_argument('--expect-text', action='append', default=[], help='Assert that important spoken content is retained; may be repeated')
parser.add_argument('--vad')
parser.add_argument('--allow-empty', action='store_true', help='Assert that non-speech audio produces no transcript')
args = parser.parse_args()
if os.name == 'nt' and pathlib.Path('C:/mingw64/bin').exists():
    os.add_dll_directory('C:/mingw64/bin')
lib = ctypes.CDLL(str(pathlib.Path(args.library).resolve()))
create = lib.ls_job_create_v2 if args.vad else lib.ls_job_create
create.argtypes = [ctypes.c_char_p] * (5 if args.vad else 4) + [ctypes.c_int32]
create.restype = ctypes.c_void_p
for name in ('ls_job_run', 'ls_job_progress'):
    getattr(lib, name).argtypes = [ctypes.c_void_p]
    getattr(lib, name).restype = ctypes.c_int32
lib.ls_job_result.argtypes = [ctypes.c_void_p]
lib.ls_job_result.restype = ctypes.c_char_p
for name in ('ls_job_cancel', 'ls_job_free'):
    getattr(lib, name).argtypes = [ctypes.c_void_p]
    getattr(lib, name).restype = None

def job(audio):
    inputs = [os.fsencode(args.model), os.fsencode(audio), args.language.encode(), args.prompt.encode()]
    if args.vad: inputs.append(os.fsencode(args.vad))
    pointer = create(*inputs, 4)
    assert pointer, 'Native job allocation failed'
    return pointer

started = time.perf_counter()
pointer = job(args.audio)
try:
    assert lib.ls_job_run(pointer) == 0, lib.ls_job_result(pointer)
    result = json.loads(lib.ls_job_result(pointer))
    if args.allow_empty: assert result['segments'] == [], 'Non-speech input fabricated text'
    else: assert result['segments'], 'No actual transcription returned'
    actual_text = ' '.join(segment['text'] for segment in result['segments']).casefold()
    for expected in args.expect_text:
        assert expected.casefold() in actual_text, f'Missing required spoken content: {expected}'
    last = 0
    for segment in result['segments']:
        assert last <= segment['startMs'] < segment['endMs'] <= result['durationMs']
        assert segment['text'].strip()
        last = segment['endMs']
    assert lib.ls_job_progress(pointer) == 100
finally:
    lib.ls_job_free(pointer)
elapsed = time.perf_counter() - started

with tempfile.TemporaryDirectory() as folder:
    invalid = pathlib.Path(folder) / 'invalid.wav'
    invalid.write_bytes(b'not a wave')
    pointer = job(str(invalid))
    try:
        assert lib.ls_job_run(pointer) == -1
        assert 'error' in json.loads(lib.ls_job_result(pointer))
    finally:
        lib.ls_job_free(pointer)
    pointer = job(args.audio)
    try:
        lib.ls_job_cancel(pointer)
        assert lib.ls_job_run(pointer) == 1
        assert json.loads(lib.ls_job_result(pointer))['error'] == 'cancelled'
    finally:
        lib.ls_job_free(pointer)
    malformed = pathlib.Path(folder) / 'truncated.wav'
    with wave.open(str(malformed), 'wb') as stream:
        stream.setparams((1, 2, 16000, 0, 'NONE', 'not compressed'))
        stream.writeframes(b'\0' * 32000)
    pointer = job(str(malformed))
    try:
        assert lib.ls_job_run(pointer) == 0
        assert json.loads(lib.ls_job_result(pointer))['segments'] == [], 'Digital silence must not fabricate words'
    finally:
        lib.ls_job_free(pointer)
    malformed.write_bytes(malformed.read_bytes()[:-100])
    pointer = job(str(malformed))
    try:
        assert lib.ls_job_run(pointer) == -1
        assert 'Truncated' in json.loads(lib.ls_job_result(pointer))['error']
    finally:
        lib.ls_job_free(pointer)

report = {'platform': os.name, 'fixtureKind': args.fixture_kind, 'language': args.language, 'prompt': args.prompt,
          'vadSha256': hashlib.sha256(pathlib.Path(args.vad).read_bytes()).hexdigest() if args.vad else None,
          'modelSha256': hashlib.sha256(pathlib.Path(args.model).read_bytes()).hexdigest(),
          'audioSha256': hashlib.sha256(pathlib.Path(args.audio).read_bytes()).hexdigest(),
          'elapsedSeconds': round(elapsed, 3), 'durationMs': result['durationMs'],
          'realTimeFactor': round(elapsed / (result['durationMs'] / 1000), 3),
          'segments': result['segments'], 'checks': [
              'neural_speech_detection_and_no_text' if args.allow_empty else 'actual_asr_inference',
              'timestamp_bounds', 'invalid_wav', 'cancellation', 'digital_silence', 'truncated_wav']}
print(json.dumps(report, ensure_ascii=False, indent=2))
if args.report:
    pathlib.Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
