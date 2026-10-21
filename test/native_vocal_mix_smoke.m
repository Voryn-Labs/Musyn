#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <math.h>

static NSData *Read(AVAsset *asset, NSArray<AVAssetTrack *> *tracks, AVAudioMix *mix) {
    NSError *error = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    NSCAssert(reader, @"Reader failed: %@", error);
    NSDictionary *settings = @{AVFormatIDKey: @(kAudioFormatLinearPCM), AVSampleRateKey: @44100,
        AVNumberOfChannelsKey: @2, AVLinearPCMIsFloatKey: @YES, AVLinearPCMBitDepthKey: @32,
        AVLinearPCMIsNonInterleaved: @NO};
    AVAssetReaderAudioMixOutput *output = [[AVAssetReaderAudioMixOutput alloc] initWithAudioTracks:tracks audioSettings:settings];
    output.audioMix = mix; [reader addOutput:output]; NSCAssert([reader startReading], @"Reader start failed");
    NSMutableData *data = [NSMutableData new]; CMSampleBufferRef sample;
    while ((sample = [output copyNextSampleBuffer])) {
        CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sample);
        size_t length = CMBlockBufferGetDataLength(block); NSMutableData *chunk = [NSMutableData dataWithLength:length];
        NSCAssert(CMBlockBufferCopyDataBytes(block, 0, length, chunk.mutableBytes) == noErr, @"PCM copy failed");
        [data appendData:chunk]; CFRelease(sample);
    }
    NSCAssert(reader.status == AVAssetReaderStatusCompleted, @"PCM read failed: %@", reader.error);
    return data;
}
int main(int argc, const char **argv) { @autoreleasepool {
    NSCAssert(argc == 2, @"Expected stem asset path");
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:@(argv[1])]];
    NSArray<AVAssetTrack *> *tracks = [[item.asset tracksWithMediaType:AVMediaTypeAudio] sortedArrayUsingComparator:^NSComparisonResult(AVAssetTrack *a, AVAssetTrack *b) { return [@(a.trackID) compare:@(b.trackID)]; }];
    NSCAssert(tracks.count == 2, @"Expected two stem tracks");
    NSData *background = Read(item.asset, @[tracks[0]], nil);
    NSData *voice = Read(item.asset, @[tracks[1]], nil);
    for (NSNumber *level in @[@0, @0.4, @1]) {
        NSCAssert(MusynApplyVocalMix(item, level.floatValue), @"Production mix rejected stems");
        NSData *mixed = Read(item.asset, tracks, item.audioMix);
        NSCAssert(mixed.length == background.length && mixed.length == voice.length, @"Mix length mismatch");
        const float *actual = mixed.bytes, *music = background.bytes, *vocals = voice.bytes;
        double error = 0, power = 0;
        for (NSUInteger i = 0; i < mixed.length / sizeof(float); i++) {
            double expected = music[i] + vocals[i] * level.floatValue;
            error += pow(actual[i] - expected, 2); power += pow(expected, 2);
        }
        NSCAssert(sqrt(error / MAX(power, 1e-12)) < 0.001, @"Vocal control changed backing or mixed wrong tracks");
    }
    NSCAssert(!MusynApplyVocalMix(item, NAN), @"Nonfinite volume accepted");
    puts("Production AVAudioMix: backing unchanged, vocals 0/0.4/1 passed");
} return 0; }
