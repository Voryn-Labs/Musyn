import Foundation
import AVFoundation
import CoreML
import Darwin

@main struct ReaderSmoke {
  static func main() async throws {
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: true)!
    for frames in [22050, 44100, 88200, 132300, 187425] {
      print("Checking \(frames) frames"); fflush(stdout)
      let input = root.appendingPathComponent("reader-\(frames).caf")
      let source = (0..<(frames * 2)).map { Float(sin(Double($0) * 0.017) * 0.25) }
      do {
        let file = try AVAudioFile(forWriting: input, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: true)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        source.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: source.count) }
        try file.write(from: buffer)
      }
      let reader = try await MusynAudioWindowReader(input: input)
      var consumed = [Float]()
      var windows = 0
      while let window = try reader.next() {
        precondition(window.position == consumed.count / 2)
        precondition(window.samples.count == MusynVocalDSP.frames * 2)
        precondition(window.samples.allSatisfy(\.isFinite))
        if windows == 0 { precondition(reader.copiedFrames == min(frames, MusynVocalDSP.frames)) }
        let emit = min(MusynAudioWindowReader.step, window.count)
        consumed.append(contentsOf: window.samples.prefix(emit * 2))
        precondition(reader.copiedFrames - consumed.count / 2 <= MusynVocalDSP.frames)
        windows += 1
      }
      precondition(consumed.count == source.count, "Lost tail or duplicated overlap: \(frames)")
      let error = zip(consumed, source).map { abs($0 - $1) }.max() ?? 0
      precondition(error < 0.000001, "Window PCM differs from input")
      let finalWindow = try reader.next()
      precondition(finalWindow == nil)
      print("\(frames) frames: \(windows) bounded windows, exact order and tail")
    }
    for channels in [1, 2] {
      let frames = 156000
      let sourceFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: AVAudioChannelCount(channels), interleaved: true)!
      let input = root.appendingPathComponent("resample-\(channels).caf")
      do {
        let file = try AVAudioFile(forWriting: input, settings: sourceFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: true)
        let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        for frame in 0..<frames {
          for channel in 0..<channels {
            buffer.floatChannelData![0][frame * channels + channel] = Float(sin(Double(frame) * 0.017) * 0.25)
          }
        }
        try file.write(from: buffer)
      }
      let reader = try await MusynAudioWindowReader(input: input)
      var count = 0
      while let window = try reader.next() {
        let emit = min(MusynAudioWindowReader.step, window.count)
        precondition(window.samples.allSatisfy(\.isFinite))
        for frame in 0..<emit { precondition(abs(window.samples[frame * 2] - window.samples[frame * 2 + 1]) < 0.00001) }
        count += emit
      }
      precondition(abs(count - 143325) <= 256, "Resampling lost the track tail")
      print("48 kHz \(channels)-channel input: stereo resampling and tail passed")
    }
    let task = Task {
      let reader = try await MusynAudioWindowReader(input: root.appendingPathComponent("reader-187425.caf"))
      withUnsafeCurrentTask { $0?.cancel() }
      return try reader.next()
    }
    do { _ = try await task.value; preconditionFailure("Cancelled reader produced audio") }
    catch is CancellationError { print("Cancellation stops the next decode window") }
  }
}
