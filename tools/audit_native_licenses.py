"""Retain per-file upstream attributions in addition to the main MIT notice.

This is a reproducible source-notice inventory, not a legal-compliance assertion.
Optional GPU/backend source is included in the repository and therefore inventoried
even though the mobile CMake configuration builds the CPU backend only.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / 'native/vendor/whisper.cpp'
OUTPUT = ROOT / 'docs/licenses'
records = []
for source in sorted(VENDOR.rglob('*')):
    if not source.is_file() or source.suffix not in {'.c', '.cpp', '.h', '.hpp', '.cu', '.cuh', '.cmake', '.metal', '.cl'}:
        continue
    content = source.read_text(encoding='utf-8', errors='replace')
    lines = [line.strip().removeprefix('//').strip().removeprefix('*').strip()
             for line in content.splitlines()
             if re.search(r'(?i)copyright|SPDX-License-Identifier:', line)]
    if lines:
        records.append({'path': source.relative_to(VENDOR).as_posix(), 'attributions': lines,
                        'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest()})

mit = (VENDOR / 'LICENSE').read_text(encoding='utf-8')
mozilla = (VENDOR / 'ggml/src/ggml-cpu/llamafile/sgemm.cpp').read_text(encoding='utf-8').split('\n\n')[0]
mozilla = '\n'.join(line.removeprefix('//').removeprefix(' ') for line in mozilla.splitlines())
sources = OUTPUT / 'sources'
yarn = (sources / 'YARN_MIT.txt').read_text(encoding='utf-8')
llvm = (sources / 'LLVM_LICENSE.txt').read_text(encoding='utf-8')
# SPDX-only MIT headers still need a full copy of the MIT terms when redistributed.
arm_intel = '\n'.join(sorted({line for record in records if any('SPDX-License-Identifier: MIT' in a for a in record['attributions'])
                              for line in record['attributions']
                              if 'Copyright' in line and ('Arm Limited' in line or 'Intel Corporation' in line)}))
body = ['Native source attributions for the pinned whisper.cpp / ggml snapshot.',
        'The mobile build uses the CPU backend. Optional backend source notices are retained',
        'for source redistribution; their inclusion does not imply those backends are enabled.',
        '', 'whisper.cpp / ggml — MIT', mit, 'Mozilla llamafile — MIT', mozilla,
        'YaRN algorithm — MIT', yarn, 'Additional MIT attributions', arm_intel,
        mit[mit.index('Permission is hereby granted'):],
        'Optional Intel SYCL / OpenVINO source — Apache 2.0 / LLVM exception', llvm,
        'Per-file source attribution inventory']
body.extend(record['path'] + '\n' + '\n'.join(record['attributions']) for record in records)
notice = '\n\n'.join(body) + '\n'
(OUTPUT / 'NATIVE_NOTICES.txt').write_text(notice, encoding='utf-8')
(ROOT / 'apps/mobile/assets/licenses/NATIVE_NOTICES.txt').write_text(notice, encoding='utf-8')
(OUTPUT / 'native-attributions.json').write_text(json.dumps(records, indent=2) + '\n', encoding='utf-8')
print(f'Retained {len(records)} per-file attribution records; notice {len(notice.encode())} bytes.')
