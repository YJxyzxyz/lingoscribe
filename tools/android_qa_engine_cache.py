"""Extract/verify our own CI engine for Debug QA; never accepts upstream SDKs.

The caller supplies the independently obtained CI APK digest and full source
commit. Every tracked native input must match that commit before use. This only
accelerates local Dart/UI QA; normal and distribution builds compile sources.
"""
import argparse
import hashlib
import json
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    with Path(path).open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()

def git(*args):
    return subprocess.run(['git', '-C', str(ROOT), *args], check=True, capture_output=True).stdout

def native_inputs():
    files = git('ls-files', 'packages/offline_engine/src', 'tools/prepare_sherpa_source.py').decode().splitlines()
    # Git may check out CRLF on Windows; C/CMake/Python native build inputs are
    # text. Only line endings are canonicalized; every other byte must match.
    return {name: hashlib.sha256((ROOT / name).read_bytes().replace(b'\r\n', b'\n')).hexdigest() for name in files}

def verify(folder):
    folder = Path(folder).resolve()
    report = json.loads((folder / 'qa-engine.json').read_text(encoding='utf-8'))
    assert report['mode'] == 'debug-qa-only'
    assert report['nativeInputs'] == native_inputs(), 'Native inputs changed; rebuild the engine from source'
    for name, expected in report['libraries'].items():
        assert name in {'arm64-v8a/liboffline_engine.so', 'arm64-v8a/libc++_shared.so', 'x86_64/liboffline_engine.so', 'x86_64/libc++_shared.so'}
        assert digest(folder / name) == expected, f'QA cached library changed: {name}'
    assert 'arm64-v8a/liboffline_engine.so' in report['libraries']
    print('Verified source-matched Debug QA engine cache')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--verify')
    parser.add_argument('--apk')
    parser.add_argument('--apk-sha256')
    parser.add_argument('--source-commit')
    parser.add_argument('--directory')
    args = parser.parse_args()
    if args.verify:
        verify(args.verify)
        return
    assert all((args.apk, args.apk_sha256, args.source_commit, args.directory))
    assert len(args.source_commit) == 40 and all(char in '0123456789abcdef' for char in args.source_commit)
    assert digest(args.apk) == args.apk_sha256, 'CI APK digest does not match'
    inputs = native_inputs()
    assert inputs, 'Native source inputs required'
    for name, expected in inputs.items():
        original = git('show', f'{args.source_commit}:{name}')
        assert hashlib.sha256(original.replace(b'\r\n', b'\n')).hexdigest() == expected, f'CI native source differs: {name}'
    folder = Path(args.directory).resolve()
    assert folder.is_relative_to(ROOT / 'build'), 'QA cache must be inside this workspace build directory'
    assert not folder.exists(), 'Use a new cache directory; never replace a cache silently'
    libraries = {}
    with zipfile.ZipFile(args.apk) as apk:
        for abi in ('arm64-v8a', 'x86_64'):
            for library in ('liboffline_engine.so', 'libc++_shared.so'):
                name = f'{abi}/{library}'
                entry = f'lib/{name}'
                if entry not in apk.namelist():
                    assert library == 'libc++_shared.so', f'Missing QA engine ABI: {abi}'
                    continue
                data = apk.read(entry)
                assert data[:5] == b'\x7fELF\x02', 'Expected real 64-bit ELF engine'
                target = folder / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                libraries[name] = hashlib.sha256(data).hexdigest()
    (folder / 'qa-engine.json').write_text(json.dumps({
        'mode': 'debug-qa-only', 'sourceCommit': args.source_commit,
        'sourceNormalization': 'CRLF to LF only; library digests are exact bytes',
        'ciApkSha256': args.apk_sha256, 'nativeInputs': inputs,
        'libraries': libraries,
    }, indent=2) + '\n', encoding='utf-8')
    verify(folder)

if __name__ == '__main__':
    main()
