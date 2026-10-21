#!/usr/bin/env python3
"""Run production timeline arithmetic through Foundation, without Flutter/UIKit."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parent.parent
source = (root / 'packages/audio_service/darwin/audio_service/Sources/audio_service/AudioServicePlugin.m').read_text()
helpers = source.split('// Musyn timeline helpers:', 1)[1].split('// End Musyn timeline helpers.', 1)[0]
helpers = helpers[helpers.index('static NSString'):]
fixture = r'''
int main(void) { @autoreleasepool {
  NSCAssert(MusynDuration(@"a", @180000, nil) == 180, @"initial duration");
  NSCAssert(MusynDuration(@"a", NSNull.null, nil) == 180, @"same-item duration survives artwork updates");
  NSCAssert(MusynDuration(@"b", nil, @"192.0") == 192, @"catalog fallback for a new song");
  NSCAssert(MusynDuration(@"c", nil, nil) == 0, @"previous song cannot donate duration");
  NSCAssert(MusynSeconds(@"182.0", 1) == 182, @"decimal catalogue seconds");
  NSCAssert(MusynSeconds(@180000, .001) == 180, @"platform milliseconds");
  NSCAssert(MusynSeconds(NSNull.null, 1) == 0, @"missing duration");
  NSCAssert(MusynSeconds(@(NAN), 1) == 0, @"nonfinite duration");
  NSCAssert(MusynElapsed(@4000, @1000, 1, 3) == 6, @"playing clock advances");
  NSCAssert(MusynElapsed(@4000, @1000, 0, 50) == 4, @"paused clock stays still");
  NSCAssert(MusynElapsed(@4000, @1000, 2, 3) == 8, @"speed respected");
  NSCAssert(MusynElapsed(@4000, @5000, 1, 3) == 4, @"future timestamp cannot rewind");
  puts("Native Now Playing timeline fixtures passed");
} return 0; }
'''
with tempfile.TemporaryDirectory(prefix='musyn-timeline-') as folder:
    main = Path(folder) / 'main.m'
    main.write_text('#import <Foundation/Foundation.h>\n#import <math.h>\n' + helpers + fixture)
    exe = Path(folder) / 'check'
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', str(main), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
