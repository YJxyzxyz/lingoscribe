"""Prepare the immutable ASR source snapshot, omitting archive symlinks/demos.

The build explicitly disables TTS and its espeak/piper dependencies. This tool
does not download model weights or copy upstream prebuilt sherpa binaries.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import tarfile
import time
import urllib.request
from pathlib import Path

REVISION = '11afbd009a7f8c08f4bcf2fc1b265d0df4670fbf'
SHA256 = '0a8db6c55dd318f4a688faba85f7760b99a6c92e8ef8864479d418531bee1ac2'
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'build/sherpa-source'
parser = argparse.ArgumentParser()
parser.add_argument('--archive', help='Optional previously downloaded source archive')
args = parser.parse_args()
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
lock = OUTPUT.with_suffix('.lock')
marker = OUTPUT / 'LINGOSCRIBE_SOURCE.json'
started = time.monotonic()
def direct_archive_urls(folder):
    # GitHub redirects these public source archive URLs to codeload. Use that
    # documented endpoint directly; upstream archive hashes remain unchanged.
    for path in (folder / 'cmake').glob('*.cmake'):
        original = path.read_text(encoding='utf-8')
        changed = re.sub(r'https://github.com/([^/]+/[^/]+)/archive/([^\s"\)]+?)\.tar\.gz',
                         r'https://codeload.github.com/\1/tar.gz/\2', original)
        changed = re.sub(r'https://github.com/([^/]+/[^/]+)/archive/([^\s"\)]+?)\.zip',
                         r'https://codeload.github.com/\1/zip/\2', changed)
        if changed != original:
            path.write_text(changed, encoding='utf-8')

def write_marker(path, record):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(record) + '\n', encoding='utf-8')
    os.replace(temporary, path)

while True:
    if (marker.exists() and json.loads(marker.read_text()).get('buildProtocol') == 2
            and json.loads(marker.read_text())['archiveSha256'] == SHA256):
        print(OUTPUT)
        raise SystemExit(0)
    try:
        lock.mkdir()
        break
    except FileExistsError:
        if time.monotonic() - started > 180:
            raise RuntimeError('Source preparation lock is still held; inspect the owning build')
        time.sleep(0.2)
try:
    if marker.exists() and json.loads(marker.read_text())['archiveSha256'] == SHA256:
        direct_archive_urls(OUTPUT)
        record = json.loads(marker.read_text())
        record.update(buildProtocol=2, patches=['Direct public codeload archive URLs; dependency hashes retained'])
        write_marker(marker, record)
        print(OUTPUT)
        raise SystemExit(0)
    archive = Path(args.archive) if args.archive else ROOT / 'build/sherpa-source.tar.gz'
    if not archive.exists():
        request = urllib.request.Request(f'https://codeload.github.com/k2-fsa/sherpa-onnx/tar.gz/{REVISION}',
                                         headers={'User-Agent': 'LingoScribe-build'})
        with urllib.request.urlopen(request, timeout=90) as source, archive.open('wb') as target:
            shutil.copyfileobj(source, target, 1024 * 1024)
    with archive.open('rb') as source:
        assert hashlib.file_digest(source, 'sha256').hexdigest() == SHA256, 'Source archive digest mismatch'
    staging = OUTPUT.with_suffix('.staging')
    assert staging.resolve().parent == (ROOT / 'build').resolve()
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir()
    with tarfile.open(archive, 'r:gz') as source:
        for entry in source:
            parts = Path(entry.name).parts[1:]
            if not parts or not entry.isfile():
                continue
            if parts[0] not in {'CMakeLists.txt', 'LICENSE', 'README.md', 'cmake', 'sherpa-onnx', 'toolchains'}:
                continue
            assert '..' not in parts and not Path(*parts).is_absolute()
            path = staging.joinpath(*parts)
            assert path.resolve().is_relative_to(staging.resolve())
            path.parent.mkdir(parents=True, exist_ok=True)
            with source.extractfile(entry) as data, path.open('wb') as target:
                shutil.copyfileobj(data, target)
    direct_archive_urls(staging)
    write_marker(staging / marker.name, {'revision': REVISION, 'archiveSha256': SHA256, 'buildProtocol': 2,
        'patches': ['Direct public codeload archive URLs; dependency hashes retained'],
        'source': f'https://github.com/k2-fsa/sherpa-onnx/tree/{REVISION}',
        'selection': 'Regular build source files only; no symlinks, examples, model weights or prebuilt sherpa binaries'})
    assert not OUTPUT.exists(), 'Do not overwrite an existing unverified source directory'
    staging.rename(OUTPUT)
    print(OUTPUT)
finally:
    lock.rmdir()
