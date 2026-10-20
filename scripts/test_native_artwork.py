#!/usr/bin/env python3
"""Exercise the production ImageIO crop on macOS without UIKit or Flutter."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
source = (root / 'ios/Runner/AppDelegate.swift').read_text()
start = source.index('private enum MusynSquareCover {')
# Extract the production type, so this harness cannot silently test a copy.
depth = 0
for end in range(source.index('{', start), len(source)):
    depth += (source[end] == '{') - (source[end] == '}')
    if depth == 0:
        break
fixture = (root / 'test/native_artwork_smoke.swift').read_text()
with tempfile.TemporaryDirectory(prefix='musyn-native-cover-') as folder:
    target = Path(folder) / 'main.swift'
    target.write_text('import Foundation\nimport CoreGraphics\nimport ImageIO\n' + source[start:end + 1] + '\n' + fixture)
    subprocess.run(['xcrun', 'swift', str(target)], check=True)
