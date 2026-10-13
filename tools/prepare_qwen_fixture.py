"""Download and verify public model fixtures for a dedicated QA installation."""
import argparse
import hashlib
import json
import shutil
import urllib.request
from pathlib import Path

MANIFEST = json.loads(Path(__file__).with_name('qwen_model_manifest.json').read_text())

def verify(directory):
    for asset in MANIFEST['files']:
        path = Path(directory) / asset['path']
        assert path.stat().st_size == asset['bytes'], f'Unexpected model size: {asset["path"]}'
        with path.open('rb') as source:
            assert hashlib.file_digest(source, 'sha256').hexdigest() == asset['sha256'], f'Unexpected model hash: {asset["path"]}'

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', required=True)
    parser.add_argument('--mirror', action='store_true')
    args = parser.parse_args()
    directory = Path(args.directory)
    for asset in MANIFEST['files']:
        path = directory / asset['path']
        if path.exists() and path.stat().st_size == asset['bytes']:
            with path.open('rb') as source:
                if hashlib.file_digest(source, 'sha256').hexdigest() == asset['sha256']:
                    continue
        path.parent.mkdir(parents=True, exist_ok=True)
        url = f'https://{"hf-mirror.com" if args.mirror else "huggingface.co"}/{MANIFEST["repository"]}/resolve/{MANIFEST["revision"]}/{asset["path"]}'
        partial = path.with_suffix(path.suffix + '.part')
        with urllib.request.urlopen(url, timeout=240) as response, partial.open('wb') as target:
            shutil.copyfileobj(response, target, 1024 * 1024)
        assert partial.stat().st_size == asset['bytes'], 'Truncated QA fixture'
        with partial.open('rb') as source:
            assert hashlib.file_digest(source, 'sha256').hexdigest() == asset['sha256'], 'Corrupted QA fixture'
        partial.replace(path)
        print(f'Verified {asset["path"]}', flush=True)
    verify(directory)
