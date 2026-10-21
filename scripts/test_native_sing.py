#!/usr/bin/env python3
"""Native DSP/lyric-art fixtures; optional local model enables a real separation test."""
from pathlib import Path
import argparse
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--model', type=Path)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='musyn-sing-check-') as temporary:
    directory = args.output or Path(temporary)
    directory.mkdir(parents=True, exist_ok=True)
    executable = Path(temporary) / 'sing-check'
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(Path(tempfile.gettempdir()) / 'musyn-swift-module-cache'),
                    str(root / 'ios/Runner/MusynVocalDSP.swift'),
                    str(root / 'ios/Runner/MusynSingEngine.swift'),
                    str(root / 'ios/Runner/MusynLyricArtwork.swift'),
                    str(root / 'test/native_sing_smoke.swift'), '-o', str(executable)], check=True)
    command = [str(executable), str(directory)]
    if args.model:
        subprocess.run(['/usr/bin/say', '-o', str(directory / 'speech.aiff'),
                        'Keep singing with the music. This is our own voice test for vocal separation. '
                        'The background melody should remain while the voice becomes quieter.'], check=True)
        command.append(str(args.model))
    subprocess.run(command, check=True, timeout=180)

    if args.model:
        source = (root / 'packages/just_audio/darwin/just_audio/Sources/just_audio/UriAudioSource.m').read_text()
        helper = source[source.index('BOOL MusynApplyVocalMix('):source.index('@implementation')]
        target = Path(temporary) / 'mix.m'
        target.write_text('#import <AVFoundation/AVFoundation.h>\n#import <math.h>\n' + helper + (root / 'test/native_vocal_mix_smoke.m').read_text())
        executable = Path(temporary) / 'mix-check'
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', '-framework', 'AVFoundation', '-framework', 'CoreMedia', str(target), '-o', str(executable)], check=True)
        subprocess.run([str(executable), str(directory / 'separated.musyn-stems.mov')], check=True, timeout=60)
