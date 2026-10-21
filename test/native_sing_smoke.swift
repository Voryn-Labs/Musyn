import Foundation
import AVFoundation
import CoreML
import ImageIO
import UniformTypeIdentifiers

@main struct SingSmoke {
  static func read(_ url: URL, track: Int? = nil) async throws -> [Float] {
    let asset = AVURLAsset(url: url)
    var tracks = try await asset.loadTracks(withMediaType: .audio).sorted { $0.trackID < $1.trackID }
    if let track = track { tracks = [tracks[track]] }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVLinearPCMIsFloatKey: true,
      AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false])
    reader.add(output); precondition(reader.startReading())
    var values = [Float]()
    while let sample = output.copyNextSampleBuffer() {
      let block = CMSampleBufferGetDataBuffer(sample)!
      var chunk = [Float](repeating: 0, count: CMBlockBufferGetDataLength(block) / 4)
      let status = chunk.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!) }
      precondition(status == noErr); values += chunk
    }
    precondition(reader.status == .completed)
    return values
  }
  static func main() async throws {
    let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let dsp = try MusynVocalDSP()
    let original = (0..<MusynVocalDSP.frames * 2).map { Float(sin(Double($0 / 2) * 0.02) * 0.3) }
    let restored = try dsp.decode(dsp.encode(original))
    let error = zip(original, restored).reduce(0.0) { $0 + Double(abs($1.0 - $1.1)) } / Double(original.count)
    precondition(error < 0.0001); print("STFT round trip: \(error)")
    for (name, line) in [("english", "Keep singing, the music carries on"), ("hindi", "तोहे सौंपा है तन-मन ये कोरा")] {
      let image = try MusynLyricArtwork.poster(current: line, next: "The next timed line")
      let png = root.appendingPathComponent(name + ".png")
      let destination = CGImageDestinationCreateWithURL(png as CFURL, UTType.png.identifier as CFString, 1, nil)!
      CGImageDestinationAddImage(destination, image, nil); precondition(CGImageDestinationFinalize(destination))
      let clip = try await MusynLyricArtwork.clip(image: image, at: root.appendingPathComponent(name + ".mp4"))
      let asset = AVURLAsset(url: clip)
      let duration = try await asset.load(.duration).seconds
      let video = try await asset.loadTracks(withMediaType: .video)
      let size = try await video.first!.load(.naturalSize)
      let audio = try await asset.loadTracks(withMediaType: .audio)
      precondition(abs(duration - 2) < 0.1 && size.width == 720 && size.height == 960 && audio.isEmpty)
    }
    print("English/Hindi posters and silent lyric clips passed")
    guard CommandLine.arguments.count > 2 else { return }
    let voice = try await read(root.appendingPathComponent("speech.aiff"))
    let frames = min(44100 * 10, voice.count / 2)
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: true)!
    let input = root.appendingPathComponent("original.caf")
    let file = try AVAudioFile(forWriting: input, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: true)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
    buffer.frameLength = AVAudioFrameCount(frames)
    var mixed = [Float](repeating: 0, count: frames * 2)
    for frame in 0..<frames {
      let music = Float(0.08 * sin(Double(frame) * 2 * .pi * 220 / 44100) + 0.04 * sin(Double(frame) * 2 * .pi * 330 / 44100))
      for channel in 0..<2 { mixed[frame * 2 + channel] = voice[frame * 2 + channel] * 0.8 + music }
    }
    mixed.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: mixed.count) }
    try file.write(from: buffer)
    let output = root.appendingPathComponent("separated.musyn-stems.mov")
    let begin = Date()
    _ = try await MusynSingEngine.prepare(input: input, output: output,
      model: URL(fileURLWithPath: CommandLine.arguments[2]), progress: { stage, value in print("\(stage) \(Int(value * 100))%") })
    let valid = await MusynSingEngine.validCache(output)
    precondition(valid)
    let background = try await read(output, track: 0)
    let vocal = try await read(output, track: 1)
    precondition(background.count == vocal.count && abs(background.count - frames * 2) < 4096)
    precondition(background.allSatisfy(\.isFinite) && vocal.allSatisfy(\.isFinite))
    let count = min(mixed.count, background.count)
    var reconstruction = 0.0, originalEnergy = 0.0, instrumentalEnergy = 0.0
    for i in 0..<count {
      reconstruction += pow(Double(background[i] + vocal[i] - mixed[i] * 0.85), 2)
      originalEnergy += pow(Double(mixed[i] * 0.85), 2)
      instrumentalEnergy += pow(Double(background[i]), 2)
    }
    let relativeError = sqrt(reconstruction / originalEnergy)
    precondition(relativeError < 0.2, "Separated stems do not reconstruct original audio: \(relativeError)")
    print("Real separation passed: \(Date().timeIntervalSince(begin))s; reconstruction error \(relativeError); instrumental/original energy \(instrumentalEnergy / originalEnergy)")
  }
}
