"""Export complete locally resolved Dart dependency notices; flag missing licenses."""
import json
import os
from pathlib import Path
from urllib.parse import unquote, urlparse
import yaml

ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT / 'apps/mobile'
lock = yaml.safe_load((MOBILE / 'pubspec.lock').read_text(encoding='utf-8'))['packages']
config = json.loads((MOBILE / '.dart_tool/package_config.json').read_text())
notices, records, missing = [], [], []
for package in config['packages']:
    name = package['name']
    if name == 'lingoscribe':
        continue
    uri = package['rootUri']
    if uri.startswith('file:'):
        path = unquote(urlparse(uri).path)
        if os.name == 'nt' and path.startswith('/'):
            path = path[1:]
        folder = Path(path)
    else:
        folder = (MOBILE / '.dart_tool' / unquote(uri)).resolve()
    candidates = [folder / candidate for candidate in ('LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING')]
    if lock.get(name, {}).get('source') == 'sdk':
        candidates.append(folder.parent.parent / 'LICENSE')
    license_file = next((p for p in candidates if p.is_file()), None)
    metadata = lock.get(name, {})
    record = {'name': name, 'version': metadata.get('version', 'sdk'), 'source': metadata.get('source', 'sdk'),
              'dependency': metadata.get('dependency', 'sdk'), 'licenseFound': license_file is not None}
    records.append(record)
    if license_file:
        notices.append(f"{'=' * 72}\n{name} {record['version']}\n{'=' * 72}\n{license_file.read_text(encoding='utf-8', errors='replace')}\n")
    else:
        missing.append(name)
output = ROOT / 'docs/licenses'
output.mkdir(parents=True, exist_ok=True)
(output / 'dart-dependencies.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(output / 'DART_NOTICES.txt').write_text('\n'.join(notices), encoding='utf-8')
print(f'Exported {len(records)} dependency records, {len(notices)} notices. Missing: {missing}')
if missing:
    raise SystemExit(1)
