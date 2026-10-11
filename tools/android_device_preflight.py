"""Read-only inventory of one explicitly authorized Android QA device."""
import argparse
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--adb', default='adb')
parser.add_argument('--device', required=True)
parser.add_argument('--report', default='build/android-device-preflight.json')
args = parser.parse_args()

def adb(*arguments):
    return subprocess.run([args.adb, '-s', args.device, *arguments], check=True,
                          capture_output=True).stdout.decode('utf-8', errors='replace').strip()

assert adb('get-state') == 'device', 'Unlock the phone and authorize USB debugging'
memory = adb('shell', 'cat', '/proc/meminfo')
memory_values = {name: int(value) for name, value in re.findall(r'^(MemTotal|MemAvailable):\s+(\d+) kB', memory, re.MULTILINE)}
disk_rows = adb('shell', 'df', '-k', '/data').splitlines()
disk_fields = disk_rows[-1].split()
properties = {name: adb('shell', 'getprop', prop) for name, prop in {
    'model': 'ro.product.model', 'manufacturer': 'ro.product.manufacturer',
    'androidRelease': 'ro.build.version.release', 'androidSdk': 'ro.build.version.sdk',
    'abis': 'ro.product.cpu.abilist', 'emulator': 'ro.kernel.qemu',
}.items()}
report = {'observedAtUtc': datetime.now(timezone.utc).isoformat(),
    'device': properties, 'memoryKiB': memory_values, 'dataAvailableKiB': int(disk_fields[3]),
    'advancedModelPreflight': memory_values.get('MemTotal', 0) * 1024 >= 6_000_000_000 and memory_values.get('MemAvailable', 0) * 1024 >= 2_000_000_000,
    'existingLingoScribePackages': adb('shell', 'pm', 'list', 'packages', 'io.github.yjxyzxyz.lingoscribe').splitlines(),
    'scope': 'Read-only device inventory. No installation, recording or performance measurement; model eligibility is a conservative development guard.'}
destination = Path(args.report)
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
