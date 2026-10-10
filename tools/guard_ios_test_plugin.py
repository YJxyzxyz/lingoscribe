"""Guard generated test-plugin imports/registration for Debug-only CocoaPods.

Called by the Xcode Flutter build phase after Flutter regenerates registrants.
Fails on an unexpected generator format rather than producing a broken release.
"""
import argparse
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('registrant')
args = parser.parse_args()
path = Path(args.registrant)
source = path.read_text(encoding='utf-8')
marker = '// LingoScribe: native integration_test is Debug-only.'
if marker in source:
    raise SystemExit(0)
block = re.compile(r'#if __has_include\(<integration_test/IntegrationTestPlugin\.h>\)\n.*?\n#endif', re.S)
call = re.compile(r'^  \[IntegrationTestPlugin registerWithRegistrar:.*?\];$', re.M)
blocks, calls = block.findall(source), call.findall(source)
if not blocks and not calls:
    raise SystemExit(0)
assert len(blocks) == 1 and len(calls) == 1, 'Flutter integration_test registrant format changed; review required'
source = block.sub(lambda match: '#if DEBUG\n' + match.group() + '\n#endif', source, count=1)
source = call.sub(lambda match: '#if DEBUG\n' + match.group() + '\n#endif', source, count=1)
path.write_text(marker + '\n' + source, encoding='utf-8')
