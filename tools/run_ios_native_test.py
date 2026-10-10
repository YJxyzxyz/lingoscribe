"""Run real decoding/Whisper integration in a new, isolated iOS Simulator."""
import argparse
import hashlib
import json
import platform
import re
import shutil
import subprocess
import time
from pathlib import Path
from codec_fixtures import create_fixtures

parser = argparse.ArgumentParser()
parser.add_argument('--bundle', required=True, help='Simulator App built from native_pipeline_test.dart')
parser.add_argument('--model', required=True)
parser.add_argument('--audio', required=True)
parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg'))
parser.add_argument('--report', default='build/ios-native-result.json')
args = parser.parse_args()
assert platform.system() == 'Darwin', 'This runner needs macOS and Xcode'
assert args.ffmpeg, 'FFmpeg is required for real codec QA fixtures'
expected = '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898'
assert hashlib.sha256(Path(args.model).read_bytes()).hexdigest() == expected
def run(*command):
    return subprocess.run(list(command), check=True, capture_output=True, text=True).stdout.strip()
def sim(*command):
    return run('xcrun', 'simctl', *command)

sdk = run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version')
runtimes = json.loads(sim('list', 'runtimes', '--json'))['runtimes']
compatible = [row for row in runtimes if row.get('isAvailable') and 'SimRuntime.iOS-' in row['identifier'] and row['version'].split('.')[0] == sdk.split('.')[0]]
assert compatible, f'No available iOS simulator runtime compatible with SDK {sdk}'
runtime = next((row for row in compatible if row['version'] == sdk), compatible[0])
device = sim('create', 'LingoScribe-native-QA', 'com.apple.CoreSimulator.SimDeviceType.iPhone-16', runtime['identifier'])
assert re.fullmatch(r'[0-9A-Fa-f-]{36}', device), 'Unexpected new simulator identifier'
package = 'io.github.yjxyzxyz.lingoscribe'
destination = Path(args.report)
destination.parent.mkdir(parents=True, exist_ok=True)
log_path = destination.with_suffix('.log')
process = None
system_process = None
system_log_path = destination.with_suffix('.system.log')
try:
    sim('boot', device)
    sim('bootstatus', device, '-b')
    sim('install', device, str(Path(args.bundle).resolve()))
    container = Path(sim('get_app_container', device, package, 'data'))
    qa = container / 'Library/Application Support/qa'
    qa.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.model, qa / 'ggml-base-q5_1.bin')
    shutil.copy2(args.audio, qa / 'sample.wav')
    create_fixtures(args.audio, qa, args.ffmpeg)
    with log_path.open('w', encoding='utf-8') as log, system_log_path.open('w', encoding='utf-8') as system_log:
        system_process = subprocess.Popen(['xcrun', 'simctl', 'spawn', device, 'log', 'stream', '--style', 'compact',
                                          '--level', 'debug', '--predicate', 'process == "Runner"'],
                                         stdout=system_log, stderr=subprocess.STDOUT, text=True)
        process = subprocess.Popen(['xcrun', 'simctl', 'launch', '--terminate-running-process', '--console', device, package],
                                   stdout=log, stderr=subprocess.STDOUT, text=True)
        started = time.monotonic()
        while time.monotonic() - started < 480:
            output = log_path.read_text(encoding='utf-8', errors='replace') + system_log_path.read_text(encoding='utf-8', errors='replace')
            status_file = qa / 'test-status.json'
            status = json.loads(status_file.read_text()) if status_file.exists() else None
            if status is not None and not status['passed']:
                raise RuntimeError(json.dumps(status) + '\n' + output[-12000:])
            if 'Some tests failed.' in output:
                raise RuntimeError(output[-12000:])
            if status is not None:
                assert status['passed'] and status['testCount'] == 2, status
                report = json.loads((qa / 'native-result.json').read_text())
                assert report['modelSha256'] == expected
                assert report['audioSha256'] == hashlib.sha256(Path(args.audio).read_bytes()).hexdigest()
                report['codecChecks'] = json.loads((qa / 'codec-result.json').read_text())
                report['runtime'] = runtime['version']
                report['simulatorDevice'] = 'iPhone 16'
                report['scope'] = 'Real iOS Simulator decoding and inference; not physical iPhone performance or store acceptance'
                report['testStatus'] = status
                destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
                print(f'iOS native assertions passed. Report: {destination}')
                break
            if process.poll() is not None:
                raise RuntimeError('Simulator console exited before test completion:\n' + output[-12000:])
            time.sleep(3)
        else:
            raise RuntimeError(f'iOS native test timed out; private QA files: {[p.name for p in qa.iterdir()]}\n' + output[-12000:])
except Exception:
    subprocess.run(['xcrun', 'simctl', 'io', device, 'screenshot', str(destination.with_suffix('.png'))], capture_output=True)
    raise
finally:
    subprocess.run(['xcrun', 'simctl', 'terminate', device, package], capture_output=True)
    if process is not None and process.poll() is None:
        process.terminate()
        process.wait(timeout=20)
    if system_process is not None and system_process.poll() is None:
        system_process.terminate()
        system_process.wait(timeout=20)
    subprocess.run(['xcrun', 'simctl', 'shutdown', device], capture_output=True)
    # Only the freshly-created dedicated simulator is removed.
    subprocess.run(['xcrun', 'simctl', 'delete', device], capture_output=True)
