"""Hash verified development artifacts and record their explicit build provenance.

Run after check_android_artifact.py. The unsigned iOS ZIP must contain the
check_ios_bundle.py report from its actual macOS build. Commit arguments identify
the builder's source checkout; hashes do not independently prove source identity.
"""
import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path


def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def commit(value):
    if not re.fullmatch(r'[0-9a-f]{40}', value):
        raise ValueError('Supply a full 40-character Git commit SHA')
    subprocess.run(['git', 'cat-file', '-e', value + '^{commit}'], check=True)
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', default='build/deliverables')
    parser.add_argument('--version', default='0.1.0')
    parser.add_argument('--android-commit', required=True)
    parser.add_argument('--ios-commit', required=True)
    parser.add_argument('--ci-run', type=int, required=True)
    parser.add_argument('--include-arm64-release-apk', action='store_true',
                        help='Include the release-mode APK signed only for development installation')
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+', args.version) or args.ci_run <= 0:
        raise ValueError('Expected a semantic version and positive CI run ID')
    android_commit, ios_commit = commit(args.android_commit), commit(args.ios_commit)
    directory = Path(args.directory)
    artifacts = []
    android_entries = [
        ('dev-android.apk', 'android-apk-check.json', 'debug-installable'),
        ('unsigned-android.aab', 'android-aab-check.json', 'unsigned-not-store-submittable'),
    ]
    if args.include_arm64_release_apk:
        android_entries.append(('dev-arm64-release.apk', 'android-release-apk-check.json',
                                'release-mode-development-signature-not-store-release'))
    for suffix, report_name, status in android_entries:
        path = directory / f'lingoscribe-{args.version}-{suffix}'
        report = json.loads((directory / report_name).read_text(encoding='utf-8'))
        sha = digest(path)
        if report.get('passed') is not True or report.get('sha256') != sha:
            raise ValueError(f'Missing, failed or stale alignment report: {path.name}')
        artifacts.append({'file': path.name, 'sha256': sha, 'bytes': path.stat().st_size,
                          'sourceCommit': android_commit, 'distributionStatus': status,
                          'staticValidationReport': report_name})
        if suffix == 'dev-arm64-release.apk':
            signature = json.loads((directory / 'android-release-apk-signature.json').read_text(encoding='utf-8-sig'))
            if (signature.get('passed') is not True or signature.get('sha256') != sha
                    or not re.fullmatch(r'[0-9a-f]{64}', signature.get('certificateSha256', ''))):
                raise ValueError('Missing, failed or stale development signature report')
            artifacts[-1]['signingCertificateSha256'] = signature['certificateSha256']
            artifacts[-1]['signatureValidationReport'] = 'android-release-apk-signature.json'
    ios = directory / f'lingoscribe-{args.version}-unsigned-ios.zip'
    with zipfile.ZipFile(ios) as archive:
        reports = [name for name in archive.namelist() if name.endswith('/bundle-check.json')]
        if len(reports) != 1:
            raise ValueError('Expected exactly one macOS bundle report in the iOS archive')
        report = json.loads(archive.read(reports[0]))
    if (report.get('passed') is not True or report.get('sourceCommit') != ios_commit
            or report.get('version') != args.version):
        raise ValueError('Failed iOS inspection or mismatched source/version')
    artifacts.append({'file': ios.name, 'sha256': digest(ios), 'bytes': ios.stat().st_size,
                      'sourceCommit': ios_commit,
                      'distributionStatus': 'unsigned-not-store-submittable',
                      'staticValidationReport': reports[0]})
    manifest = {
        'artifacts': artifacts,
        'ciRun': f'https://github.com/YJxyzxyz/lingoscribe/actions/runs/{args.ci_run}',
        'provenance': 'Source commits are explicit builder assertions; artifact SHA-256 verifies bytes, not source identity.',
        'scope': 'Development artifacts; static checks do not replace signed releases, phone benchmarks or store acceptance.',
    }
    (directory / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'Recorded {len(artifacts)} artifacts in {directory / "manifest.json"}')


if __name__ == '__main__':
    main()
