#!/usr/bin/env python3
"""Package already-built Apple Silicon products without legacy reference data."""

import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--verify-launch', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+', args.version):
        parser.error('version must be a numeric major.minor.patch version')
    build = args.build_dir.resolve()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = args.version
    app_name = f'QSB-v{version}-macos-arm64'
    cli_name = f'qsb-v{version}-macos-arm64'
    # Separate staging parents also work on case-insensitive macOS filesystems.
    app_root = output / 'app-staging' / app_name
    cli_root = output / 'cli-staging' / cli_name
    app = app_root / 'QSBMacApp.app'
    resources = app / 'Contents/Resources'
    macos = app / 'Contents/MacOS'
    resources.mkdir(parents=True, exist_ok=True)
    macos.mkdir(parents=True, exist_ok=True)
    cli_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(build / 'QSBMacApp', macos / 'QSBMacApp')
    shutil.copy2(build / 'qsb', cli_root / 'qsb')
    shutil.copy2(ROOT / 'Sources/QSBMacApp/Resources/AppIcon.icns', resources / 'AppIcon.icns')
    shutil.copytree(build / 'QSB_QSBMacApp.bundle', resources / 'QSB_QSBMacApp.bundle', dirs_exist_ok=True)
    info = {
        'CFBundleExecutable': 'QSBMacApp', 'CFBundleIdentifier': 'dev.qsb.QSBMacApp',
        'CFBundleName': 'QSB', 'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'AppIcon',
        'CFBundleShortVersionString': version, 'CFBundleVersion': version,
        'LSMinimumSystemVersion': '14.0', 'NSPrincipalClass': 'NSApplication',
        'NSHumanReadableCopyright': 'Copyright © 2026 Humberto A. and QSB contributors.',
    }
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    for directory in [app_root, cli_root]:
        shutil.copy2(ROOT / 'LICENSE', directory / 'LICENSE')
        (directory / 'README.txt').write_text(
            f'QSB {version} — macOS 14 or later, Apple Silicon (arm64).\n'
            'Project: https://github.com/kubrick06010/qsb\n'
            'Help: https://kubrick06010.github.io/qsb/\n'
            'The app is ad-hoc signed, not Developer ID signed or notarized.\n'
            'HiGHS is optional and not included. License: MIT (see LICENSE).\n'
        )
    subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    for binary in [macos / 'QSBMacApp', cli_root / 'qsb']:
        subprocess.run(['lipo', str(binary), '-verify_arch', 'arm64'], check=True)
    if args.verify_launch:
        subprocess.run(['open', '-n', str(app)], check=True)
        time.sleep(3)
        pids = subprocess.check_output(['pgrep', '-f', re.escape(str(macos / 'QSBMacApp'))], text=True)
        for pid in pids.split():
            os.kill(int(pid), signal.SIGTERM)
    subprocess.run(['ditto', '-c', '-k', '--norsrc', '--keepParent', str(app_root), str(output / (app_name + '.zip'))], check=True)
    subprocess.run(['tar', '-czf', str(output / (cli_name + '.tar.gz')), '-C', str(cli_root.parent), cli_name],
                   env={**os.environ, 'COPYFILE_DISABLE': '1'}, check=True)
    assets = [output / (app_name + '.zip'), output / (cli_name + '.tar.gz')]
    (output / 'BINARY-SHA256SUMS.txt').write_text(''.join(
        hashlib.sha256(asset.read_bytes()).hexdigest() + '  ' + asset.name + '\n' for asset in assets
    ))
    print('Release binaries packaged, signed ad-hoc, and verified.')


if __name__ == '__main__':
    main()
