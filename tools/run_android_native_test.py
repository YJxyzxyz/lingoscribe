"""Run the real native integration APK on an explicitly selected QA device."""
import argparse
import hashlib
import json
import subprocess
import shutil
import tempfile
import time
import os
import re
from pathlib import Path
from codec_fixtures import create_fixtures
from prepare_qwen_fixture import verify as verify_qwen, MANIFEST as QWEN_MANIFEST

parser = argparse.ArgumentParser()
parser.add_argument('--adb', default='adb')
parser.add_argument('--device', required=True, help='Dedicated QA emulator/device serial')
parser.add_argument('--apk', required=True, help='APK built from integration_test/native_pipeline_test.dart')
parser.add_argument('--package-id', default='io.github.yjxyzxyz.lingoscribe.qa')
parser.add_argument('--aapt', help='Android build-tools aapt; automatically found in ANDROID_HOME/ANDROID_SDK_ROOT')
model_group = parser.add_mutually_exclusive_group(required=True)
model_group.add_argument('--model')
model_group.add_argument('--qwen-directory')
parser.add_argument('--audio', required=True, help='Licensed English fixture containing the word country; see TESTING.md')
parser.add_argument('--report', default='build/android-native-result.json')
parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg'), help='Used only to create local codec QA fixtures')
args = parser.parse_args()
package = args.package_id
assert package in {'io.github.yjxyzxyz.lingoscribe', 'io.github.yjxyzxyz.lingoscribe.qa'}, 'Unknown QA package'
command = [args.adb, '-s', args.device]
def adb(*arguments, **kwargs):
    return subprocess.run(command + list(arguments), check=True, **kwargs)

device_state = adb('get-state', capture_output=True).stdout.decode().strip()
assert device_state == 'device', f'Device is not authorized: {device_state}'
emulator = adb('shell', 'getprop', 'ro.kernel.qemu', capture_output=True).stdout.decode().strip() == '1'
assert emulator or package.endswith('.qa'), 'Physical-device tests require the independent .qa installation'
sdk_root = os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
if not args.aapt and sdk_root:
    candidates = sorted(Path(sdk_root).glob('build-tools/*/aapt*'))
    args.aapt = next((str(path) for path in reversed(candidates) if path.name in {'aapt', 'aapt.exe'}), None)
assert args.aapt, 'Pass --aapt or set ANDROID_SDK_ROOT before any installation'
badging = subprocess.run([args.aapt, 'dump', 'badging', args.apk], check=True, capture_output=True).stdout.decode('utf-8', errors='replace')
apk_package = re.search(r"^package: name='([^']+)'", badging, re.MULTILINE)
assert apk_package and apk_package.group(1) == package, 'APK package does not match the explicitly selected QA installation'
assert 'application-debuggable' in badging, 'Native fixture injection requires a debug QA APK'

expected = '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898'
if args.qwen_directory:
    verify_qwen(args.qwen_directory)
else:
    model = Path(args.model)
    assert hashlib.sha256(model.read_bytes()).hexdigest() == expected, 'Model must match the official pinned Base Q5 file'
adb('shell', 'am', 'force-stop', package, capture_output=True)
adb('install', '-r', args.apk)
adb('shell', 'pm', 'grant', package, 'android.permission.RECORD_AUDIO')
adb('shell', 'run-as', package, 'mkdir', '-p', 'files/qa')
inputs = [(Path(args.audio), 'sample.wav')]
if args.qwen_directory:
    adb('shell', 'run-as', package, 'mkdir', '-p', 'files/qa/qwen/tokenizer')
    inputs += [(Path(args.qwen_directory) / asset['path'], 'qwen/' + asset['path']) for asset in QWEN_MANIFEST['files']]
else:
    inputs += [(model, 'ggml-base-q5_1.bin')]
for source, name in inputs:
    with source.open('rb') as input_file:
        adb('exec-in', 'run-as', package, 'sh', '-c', f'cat > files/qa/{name}', stdin=input_file)
if not args.qwen_directory:
    assert args.ffmpeg, 'FFmpeg is required to create real codec test fixtures'
    with tempfile.TemporaryDirectory(prefix='lingoscribe-codec-qa-') as folder:
        for fixture in create_fixtures(args.audio, folder, args.ffmpeg):
            with fixture.open('rb') as input_file:
                adb('exec-in', 'run-as', package, 'sh', '-c', f'cat > files/qa/{fixture.name}', stdin=input_file)
adb('shell', 'run-as', package, 'rm', '-f', 'files/qa/native-result.json', 'files/qa/codec-result.json', 'files/qa/microphone-result.json', 'files/qa/test-status.json')
adb('shell', 'am', 'start', '-n', f'{package}/io.github.yjxyzxyz.lingoscribe.MainActivity')
started = time.monotonic()
memory_samples = []
last_memory_sample = -10.0
last_pid = None
while time.monotonic() - started < (900 if args.qwen_directory else 600):
    pid = subprocess.run(command + ['shell', 'pidof', package], capture_output=True).stdout.decode().strip()
    if pid:
        last_pid = pid.split()[0]
    elif last_pid is not None:
        crash_log = adb('logcat', '-d', '--pid', last_pid, capture_output=True).stdout.decode('utf-8', errors='replace')
        raise SystemExit('QA process exited before completion:\n' + crash_log[-12000:])
    log = adb('logcat', '-d', '--pid', pid.split()[0], '-s', 'flutter', capture_output=True).stdout.decode('utf-8', errors='replace') if pid else ''
    if pid and time.monotonic() - started - last_memory_sample >= 5:
        memory = subprocess.run(command + ['shell', 'dumpsys', 'meminfo', package], capture_output=True).stdout.decode('utf-8', errors='replace')
        pss = re.search(r'TOTAL PSS:\s+(\d+)', memory) or re.search(r'^\s*TOTAL\s+(\d+)', memory, re.MULTILINE)
        rss = re.search(r'TOTAL RSS:\s+(\d+)', memory)
        if pss:
            memory_samples.append({'elapsedSeconds': round(time.monotonic() - started, 3), 'pssKiB': int(pss.group(1)), 'rssKiB': int(rss.group(1)) if rss else None})
        last_memory_sample = time.monotonic() - started
    if 'Some tests failed.' in log:
        print(log)
        raise SystemExit('Native integration assertions failed')
    status_response = subprocess.run(command + ['exec-out', 'run-as', package, 'cat', 'files/qa/test-status.json'], capture_output=True)
    # adb exec-out can return 0 with an empty body before the private file exists.
    status = json.loads(status_response.stdout) if status_response.stdout.strip().startswith(b'{') else None
    if status is not None and not status['passed']:
        raise SystemExit(f'Native assertions failed: {status}')
    if status is not None:
        assert status['passed'] and status['testCount'] == (1 if args.qwen_directory else 3), status
        response = adb('exec-out', 'run-as', package, 'cat', 'files/qa/native-result.json', capture_output=True).stdout
        report = json.loads(response)
        if args.qwen_directory:
            assert report['engine'] == 'qwen3'
            assert report['modelHashes'] == {asset['path']: asset['sha256'] for asset in QWEN_MANIFEST['files']}
        else:
            codecs = adb('exec-out', 'run-as', package, 'cat', 'files/qa/codec-result.json', capture_output=True).stdout
            report['codecChecks'] = json.loads(codecs)
            report['microphoneChecks'] = json.loads(adb('exec-out', 'run-as', package, 'cat', 'files/qa/microphone-result.json', capture_output=True).stdout)
            report['microphoneChecks']['scope'] = 'Real native microphone lifecycle on ' + ('a dedicated emulator' if emulator else 'a physical phone') + '; not human voice accuracy or power measurement'
            assert report['modelSha256'] == expected
        assert report['audioSha256'] == hashlib.sha256(Path(args.audio).read_bytes()).hexdigest()
        report['deviceSerial'] = args.device
        report['packageId'] = package
        with Path(args.apk).open('rb') as apk_file:
            report['apkSha256'] = hashlib.file_digest(apk_file, 'sha256').hexdigest()
        report['physicalDevice'] = not emulator
        report['deviceModel'] = adb('shell', 'getprop', 'ro.product.model', capture_output=True).stdout.decode().strip()
        report['androidRelease'] = adb('shell', 'getprop', 'ro.build.version.release', capture_output=True).stdout.decode().strip()
        report['androidSdk'] = adb('shell', 'getprop', 'ro.build.version.sdk', capture_output=True).stdout.decode().strip()
        report['abi'] = adb('shell', 'getprop', 'ro.product.cpu.abi', capture_output=True).stdout.decode().strip()
        report['scope'] = 'Real native pipeline on ' + ('a physical phone' if not emulator else 'a dedicated emulator') + '; debug timing is not a release performance or power benchmark'
        report['testStatus'] = status
        report['memory'] = {'sampleIntervalSeconds': 5, 'samples': memory_samples,
            'peakSampledPssKiB': max((sample['pssKiB'] for sample in memory_samples), default=None),
            'peakSampledRssKiB': max((sample['rssKiB'] for sample in memory_samples if sample['rssKiB'] is not None), default=None),
            'scope': 'ADB dumpsys samples across the complete debug integration run including fixture import; sampled maxima can miss short peaks. Not power measurement.'}
        destination = Path(args.report)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(f'Native integration assertions passed. Report: {destination}')
        break
    time.sleep(3)
else:
    raise SystemExit('Native integration timed out; inspect device logs')
