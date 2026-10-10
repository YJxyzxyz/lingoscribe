"""Export actual CocoaPods acknowledgements and reject unaccounted native pods.

The app retains Flutter/Dart/plugin licenses through Flutter's LicenseRegistry.
This audit additionally detects native pods without a corresponding Flutter
plugin, which would require explicit packaged notices before distribution.
"""
import argparse
import json
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='build/ios-license-audit')
args = parser.parse_args()
mobile = ROOT / 'apps/mobile'
plugins = json.loads((mobile / '.flutter-plugins-dependencies').read_text())['plugins']['ios']
covered = {plugin['name'] for plugin in plugins} | {'Flutter'}
ack = mobile / 'ios/Pods/Target Support Files/Pods-Runner/Pods-Runner-acknowledgements.plist'
entries = plistlib.loads(ack.read_bytes())['PreferenceSpecifiers']
records = [{'name': row['Title'], 'licenseText': row['FooterText']}
           for row in entries if row.get('Type') == 'PSGroupSpecifier' and row.get('Title')
           and row['Title'] not in {'Acknowledgements', 'Acknowledgments'} and row.get('FooterText')]
assert records, 'No CocoaPods acknowledgements found'
unexpected = [row['name'] for row in records if row['name'] not in covered]
assert not unexpected, f'Native pods need explicit packaged license review: {unexpected}'
assert all(len(row['licenseText'].strip()) > 40 for row in records), 'Empty or abbreviated CocoaPods license'
output = ROOT / args.output
output.mkdir(parents=True, exist_ok=True)
(output / 'ios-pods-notices.json').write_text(json.dumps(records, indent=2) + '\n', encoding='utf-8')
(output / 'IOS_PODS_NOTICES.txt').write_text('\n\n'.join(row['name'] + '\n' + row['licenseText'] for row in records) + '\n', encoding='utf-8')
(output / 'Podfile.lock').write_bytes((mobile / 'ios/Podfile.lock').read_bytes())
print(f'Exported {len(records)} resolved native pod notices; no additional external pods.')
