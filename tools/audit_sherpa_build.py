"""Archive resolved ASR-native dependency notices; reject unwanted build scope."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--build-directory', required=True)
parser.add_argument('--output', default='build/sherpa-license-audit')
args = parser.parse_args()
build = Path(args.build_directory)
scope = json.loads((build / 'sherpa-build-scope.json').read_text())
assert scope['sourceBuilt'] and not any(scope[name] for name in ('tts', 'gpu', 'diarization', 'websocket'))
folders = [ROOT / 'build/sherpa-source'] + sorted((build / '_deps').glob('*-src'))
assert not any('piper' in p.name or 'espeak' in p.name for p in folders), 'Unexpected synthesis dependency'
records, texts = [], []
names = ('LICENSE', 'LICENSE.txt', 'LICENSE.md', 'LICENSE.MIT', 'COPYING', 'COPYING.MPL2', 'COPYING.BSD')
for folder in folders:
    notices = [folder / name for name in names if (folder / name).is_file()]
    if (folder / 'LICENSES/BSD-3-Clause').is_file():
        notices.append(folder / 'LICENSES/BSD-3-Clause')
    if folder.name == 'onnxruntime-src':
        # These CPU archives omit notices; package the full version-matched
        # upstream MIT license and third-party notices retained in the repo.
        notices += list((ROOT / 'docs/licenses/sources/onnxruntime-1.28.2').iterdir())
    assert notices, f'No dependency notices found: {folder.name}'
    for notice in notices:
        text = notice.read_text(encoding='utf-8', errors='replace')
        assert len(text.strip()) > 40
        records.append({'dependency': folder.name, 'notice': notice.name,
                        'sha256': hashlib.sha256(notice.read_bytes()).hexdigest()})
        texts.append(f'{folder.name} / {notice.name}\n{text}\n')
        if folder.name != 'onnxruntime-src':
            packaged = (ROOT / 'apps/mobile/assets/licenses/SHERPA_NOTICES.txt').read_text(encoding='utf-8')
            normalized = '\n'.join(line.rstrip() for line in text.splitlines()).strip()
            assert normalized in packaged, f'Notice must be packaged in the app: {folder.name}/{notice.name}'
output = ROOT / args.output
output.mkdir(parents=True, exist_ok=True)
(output / 'SHERPA_NOTICES.txt').write_text('\n\n'.join(texts), encoding='utf-8')
(output / 'sherpa-notices.json').write_text(json.dumps({'buildScope': scope, 'notices': records,
    'scope': 'Resolved dependency notices and build-option checks; not an independent legal certification'}, indent=2) + '\n')
print(f'Archived {len(records)} actual dependency notices')
