"""Verify an actual interrupted recorder file was repaired without changing PCM."""
import argparse
import hashlib
import json
import wave
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('before', help='Actual WAV pulled after process kill, before app restart')
parser.add_argument('after', help='Same file pulled after app restart')
parser.add_argument('--report', required=True)
args = parser.parse_args()
before, after = Path(args.before).read_bytes(), Path(args.after).read_bytes()
assert len(before) > 44 and before[:44] == bytes(44), 'Expected the interrupted native recorder header'
assert len(before) == len(after) and before[44:] == after[44:], 'Original recorded PCM must be preserved exactly'
with wave.open(args.after) as audio:
    assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (1, 2, 16000)
    duration = audio.getnframes() / 16000
report = {'scope': 'Actual Android emulator process-kill recovery, not iOS or low-storage validation',
          'beforeSha256': hashlib.sha256(before).hexdigest(), 'afterSha256': hashlib.sha256(after).hexdigest(),
          'originalPcmSha256': hashlib.sha256(before[44:]).hexdigest(), 'durationSeconds': duration,
          'bytes': len(after), 'checks': ['zero_header_repaired', 'original_pcm_identical', 'valid_pcm16_mono_16k_wav'],
          'passed': True}
Path(args.report).write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
