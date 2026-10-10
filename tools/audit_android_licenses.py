"""Extract licenses for the resolved Android runtime, not the entire Gradle cache."""
import argparse
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('dependencies', help='Gradle :app:dependencies --configuration releaseRuntimeClasspath output')
parser.add_argument('--cache', default=str(Path.home() / '.gradle/caches/modules-2/files-2.1'))
parser.add_argument('--output', default='docs/licenses/android-dependencies.json')
args = parser.parse_args()
resolved = set()
for line in Path(args.dependencies).read_text(encoding='utf-8-sig').splitlines():
    match = re.search(r'--- ([\w.-]+):([\w.-]+)(?::([^\s]+))?(?: -> ([^\s]+))?', line)
    if match and ' FAILED' not in line:
        group, artifact, version, selected = match.groups()
        version = selected or version
        if version and ':' not in version:
            resolved.add((group, artifact, version))
records = []
namespace = {'m': 'http://maven.apache.org/POM/4.0.0'}
def metadata(group, artifact, version, seen=None):
    coordinate = (group, artifact, version)
    seen = set() if seen is None else seen
    if coordinate in seen:
        return [], None, None, False
    seen.add(coordinate)
    files = list((Path(args.cache) / group / artifact / version).glob('**/*.pom'))
    if not files:
        return [], None, None, False
    pom = ET.parse(files[0]).getroot()
    licenses = [{key: entry.findtext(f'm:{key}', '', namespace) for key in ('name', 'url', 'distribution')}
                for entry in pom.findall('m:licenses/m:license', namespace)]
    source = pom.findtext('m:url', '', namespace)
    origin = ':'.join(coordinate) if licenses else None
    parent = pom.find('m:parent', namespace)
    if not licenses and parent is not None:
        inherited, parent_source, origin, _ = metadata(
            *(parent.findtext(f'm:{key}', '', namespace) for key in ('groupId', 'artifactId', 'version')), seen=seen)
        licenses = inherited
        source = source or parent_source
    return licenses, source, origin, True

for group, artifact, version in sorted(resolved):
    licenses, source, origin, found = metadata(group, artifact, version)
    if group == 'io.flutter' and not licenses:
        # These pinned engine artifacts are distributed under the Flutter SDK license.
        licenses = [{'name': 'BSD-3-Clause', 'url': 'https://github.com/flutter/flutter/blob/3.47.7/LICENSE', 'distribution': 'repo'}]
        source = 'https://github.com/flutter/flutter/tree/3.47.7'
        origin = 'Flutter SDK LICENSE; engine revision is recorded in artifact version'
    records.append({'group': group, 'artifact': artifact, 'version': version,
                    'licenses': licenses, 'source': source, 'licenseOrigin': origin, 'pomFound': found})
output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
missing = [f"{row['group']}:{row['artifact']}:{row['version']}" for row in records if not row['licenses']]
print(json.dumps({'resolvedArtifacts': len(records), 'missingLicenseMetadata': missing}, indent=2))
if missing:
    raise SystemExit(1)
