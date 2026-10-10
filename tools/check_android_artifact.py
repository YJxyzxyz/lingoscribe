"""Check real APK/AAB ELF alignment and report hashes without external tooling."""
import argparse
import hashlib
import json
import struct
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('artifact')
parser.add_argument('--report')
args = parser.parse_args()
artifact = Path(args.artifact)
libraries = []
abis = {}
with zipfile.ZipFile(artifact) as package:
    for entry in package.infolist():
        if not entry.filename.endswith('.so'):
            continue
        data = package.read(entry)
        assert data[:4] == b'\x7fELF' and data[5] == 1, f'Expected little-endian ELF: {entry.filename}'
        abi = entry.filename.split('/')[-2]
        abis.setdefault(abi, set()).add(entry.filename.split('/')[-1])
        is64 = data[4] == 2
        offset = struct.unpack_from('<Q' if is64 else '<I', data, 32 if is64 else 28)[0]
        size, count = struct.unpack_from('<HH', data, 54 if is64 else 42)
        loads = []
        for index in range(count):
            fields = struct.unpack_from('<IIQQQQQQ' if is64 else '<IIIIIIII', data, offset + size * index)
            if fields[0] == 1:
                loads.append({'offset': fields[2] if is64 else fields[1], 'virtualAddress': fields[3] if is64 else fields[2], 'alignment': fields[7]})
        assert loads, f'No loadable segments: {entry.filename}'
        valid = all(segment['alignment'] >= 16384 and
                    (segment['offset'] - segment['virtualAddress']) % 16384 == 0 for segment in loads)
        # APK stored native entries must be 16 KiB zip aligned as well as ELF aligned.
        with artifact.open('rb') as raw:
            raw.seek(entry.header_offset)
            header = raw.read(30)
        name, extra = struct.unpack_from('<HH', header, 26)
        data_offset = entry.header_offset + 30 + name + extra
        zip_valid = artifact.suffix != '.apk' or entry.compress_type != zipfile.ZIP_STORED or data_offset % 16384 == 0
        libraries.append({'path': entry.filename, 'sha256': hashlib.sha256(data).hexdigest(),
                          'loadSegments': loads, 'elf16KiB': valid, 'zip16KiB': zip_valid,
                          'compressed': entry.compress_type != zipfile.ZIP_STORED})
required = {'libflutter.so', 'liboffline_engine.so'}
if artifact.suffix == '.aab':
    required.add('libapp.so')
incomplete = {abi: sorted(required - files) for abi, files in abis.items() if required - files}
report = {'artifact': artifact.name, 'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest(),
          'libraries': libraries, 'incompleteAbis': incomplete,
          'passed': bool(libraries) and not incomplete and all(row['elf16KiB'] and row['zip16KiB'] for row in libraries),
          'scope': 'Static package alignment only; not a 16 KiB device execution test'}
encoded = json.dumps(report, indent=2)
if args.report:
    Path(args.report).write_text(encoded + '\n', encoding='utf-8')
print(encoded)
if not report['passed']:
    raise SystemExit(1)
