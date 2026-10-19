"""Check distribution identity, icon files, and source-feed integrity."""
import json
from pathlib import Path
import plistlib
import re
import struct
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
text = (root / 'pubspec.yaml').read_text()
assert 'name: musyn\n' in text
version = re.search(r'^version: (\S+)\+', text, re.M)[1]
assert f"'{version}'" in (root / 'lib/constants/version.dart').read_text()
project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
ids = re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', project)
assert len(ids) == 6 and all(item in {'com.vorynlabs.musyn', 'com.vorynlabs.musyn.RunnerTests'} for item in ids)
info = plistlib.loads((root / 'ios/Runner/Info.plist').read_bytes())
assert info['CFBundleDisplayName'] == info['CFBundleName'] == 'Musyn'
assert info['UIBackgroundModes'] == ['audio']
assert info['CFBundleURLTypes'][0]['CFBundleURLSchemes'] == ['musyn']
ET.parse(root / 'ios/Runner/Base.lproj/LaunchScreen.storyboard')
icons = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for image in json.loads((icons / 'Contents.json').read_text())['images']:
    data = (icons / image['filename']).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    width, height = struct.unpack('>II', data[16:24])
    pixels = int(float(image['size'].split('x')[0]) * int(image['scale'][0]))
    assert width == height == pixels
    assert data[25] in {0, 2, 3}, 'App icons must not carry an alpha channel'
feed = json.loads((root / 'source.json').read_text())
assert feed == json.loads((root / 'apps.json').read_text())
assert feed['identifier'] == 'com.vorynlabs.musyn.source'
for app in feed['apps']:
    assert app['name'] == 'Musyn' and app['bundleIdentifier'] == 'com.vorynlabs.musyn'
    assert app['size'] > 0 and app['downloadURL'].endswith('/Musyn.ipa')
print(f'Musyn {version}: identity, launch screen, icons and source feeds verified')
