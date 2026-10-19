"""Generate the public 0.1 feed only from an existing built IPA."""
import argparse
import datetime
import json
from pathlib import Path
import plistlib
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--ipa', type=Path, required=True)
parser.add_argument('--tag', required=True)
args = parser.parse_args()
with zipfile.ZipFile(args.ipa) as archive:
    info = plistlib.loads(archive.read('Payload/Runner.app/Info.plist'))
assert info['CFBundleIdentifier'] == 'com.vorynlabs.musyn', info
assert info['CFBundleDisplayName'] == 'Musyn', info
version = info['CFBundleShortVersionString']
assert args.tag == f'v{version}'
feed = json.loads(Path('source.json').read_text())
url = f'https://github.com/Voryn-Labs/Musyn/releases/download/{args.tag}/Musyn.ipa'
release = {'version': version, 'buildVersion': str(info['CFBundleVersion']), 'date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'downloadURL': url, 'size': args.ipa.stat().st_size, 'minOSVersion': '15.0',
           'localizedDescription': 'Musyn by Voryn Labs. Multi-source playback, offline downloads, synced lyrics and a focused player.'}
feed['apps'] = [{'name': 'Musyn', 'bundleIdentifier': info['CFBundleIdentifier'],
    'developerName': 'Voryn Labs', 'subtitle': 'Music, in your rhythm.',
    'localizedDescription': 'A focused iPhone music player with YouTube Music, JioSaavn AAC, synced lyrics and offline downloads. Sign or import the unsigned IPA with a compatible installer.',
    'iconURL': feed['iconURL'], 'tintColor': 'FFC5A7', 'versions': [release],
    'appPermissions': {'entitlements': [], 'privacy': {}},
    'version': version, 'versionDate': release['date'], 'versionDescription': release['localizedDescription'],
    'downloadURL': url, 'size': release['size'], 'minOSVersion': '15.0'}]
for filename in ['apps.json', 'source.json']:
    Path(filename).write_text(json.dumps(feed, indent=2) + '\n')
print(f'Generated Musyn {version} feed from {release["size"]} byte IPA')
