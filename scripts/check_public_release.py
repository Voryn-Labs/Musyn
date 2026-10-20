#!/usr/bin/env python3
"""Reject the removed provider material in tracked files and packaged IPAs."""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
blocked = set((root / 'scripts/blocked_provider_material.sha256').read_text().split())
def check(data, name):
    for candidate in re.finditer(rb'[0-9]{8}', data):
        if hashlib.sha256(candidate.group()).hexdigest() in blocked:
            raise SystemExit('Removed provider material detected in ' + name)
parser = argparse.ArgumentParser()
parser.add_argument('--ipa', type=Path)
args = parser.parse_args()
if args.ipa:
    with zipfile.ZipFile(args.ipa) as archive:
        for member in archive.infolist():
            if not member.is_dir():
                check(archive.read(member), member.filename)
    print('Packaged IPA contains no blocked provider material')
else:
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
    for relative in paths:
        path = root / relative
        if relative and path.is_file():
            check(path.read_bytes(), relative)
    service = (root / 'lib/services/jiosaavn_service.dart').read_text()
    assert 'ProviderAccess.instance.mediaKey' in service
    assert not (root / 'lib/services/device_log_upload.dart').exists()
    print('Public source credential and automatic-upload guards passed')
