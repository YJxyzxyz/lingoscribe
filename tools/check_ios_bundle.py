"""Inspect actual unsigned iOS bundle assets, FFI exports and privacy manifests."""
import argparse
import hashlib
import json
import plistlib
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('bundle')
parser.add_argument('--nm', default='nm')
parser.add_argument('--commit')
parser.add_argument('--report')
args = parser.parse_args()
root = Path(args.bundle)
info = plistlib.loads((root / 'Info.plist').read_bytes())
manifests = [{'path': path.relative_to(root).as_posix(), 'declaration': plistlib.loads(path.read_bytes())}
             for path in sorted(root.rglob('*.xcprivacy'))]
tracking = [row['path'] for row in manifests if row['declaration'].get('NSPrivacyTracking') or
            row['declaration'].get('NSPrivacyTrackingDomains')]
collected = [row['path'] for row in manifests if row['declaration'].get('NSPrivacyCollectedDataTypes')]
detector = root / 'Frameworks/App.framework/flutter_assets/assets/models/ggml-silero-v6.2.0.bin'
digest = hashlib.sha256(detector.read_bytes()).hexdigest()
native = root / 'Frameworks/offline_engine.framework/offline_engine'
symbols = subprocess.run([args.nm, '-g', str(native)], check=True, capture_output=True, text=True).stdout
required = ['ls_job_create_v2', 'ls_job_run', 'ls_job_progress', 'ls_job_phase', 'ls_job_cancel', 'ls_job_result', 'ls_job_free']
exports = {name: any(line.endswith(f' T _{name}') for line in symbols.splitlines()) for name in required}
report = {'sourceCommit': args.commit, 'bundleId': info.get('CFBundleIdentifier'),
          'version': info.get('CFBundleShortVersionString'), 'build': info.get('CFBundleVersion'),
          'minimumOS': info.get('MinimumOSVersion'), 'microphoneUsage': info.get('NSMicrophoneUsageDescription'),
          'nativeSha256': hashlib.sha256(native.read_bytes()).hexdigest(), 'nativeExports': exports,
          'detectorSha256': digest, 'manifests': manifests,
          'trackingDeclarations': tracking, 'collectedDataDeclarations': collected,
          'scope': 'Static unsigned bundle inspection; not signed-device runtime or App Store acceptance'}
localizations = {language: (root / f'{language}.lproj/InfoPlist.strings').exists() for language in ('en', 'zh-Hans')}
report['permissionLocalizations'] = localizations
report['developmentFrameworks'] = [path.name for path in (root / 'Frameworks').glob('*integration_test*')]
report['passed'] = bool(manifests) and not tracking and not collected and all(exports.values()) and bool(report['microphoneUsage']) and digest == '2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987'
if report['developmentFrameworks']:
    report['passed'] = False
if localizations and not all(localizations.values()):
    report['passed'] = False
encoded = json.dumps(report, ensure_ascii=False, indent=2)
if args.report:
    Path(args.report).write_text(encoded + '\n', encoding='utf-8')
print(encoded)
if not report['passed']:
    raise SystemExit(1)
