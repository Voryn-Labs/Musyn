import Foundation
import AVFoundation
import CoreML
import CryptoKit

// Model provenance and full MIT notices: assets/licenses/vocal-separator-NOTICE.txt.
enum MusynSingError: LocalizedError {
  case failed(String)
  var errorDescription: String? { if case let .failed(message) = self { return message }; return nil }
}

enum MusynVocalModel {
  static let revision = "14326ee9a607d47ebfe962e0ac18ef6c76746929"
  static let files: [(String, Int, String)] = [
    ("metadata.json", 2383, "757200c870bd4c5e5b70130c9edbd60029bd81c779b504c57ddcd624597f30e9"),
    ("coremldata.bin", 484, "e533e0c22c3f185e5b8871d2b897111e64420736daa7dc7c239206ca2519d428"),
    ("analytics/coremldata.bin", 243, "205b1d1d16603c69b4abdfa54b29df71164a16ca4f16a1cf436e7e33ce0b1407"),
    ("model.mil", 715945, "d3b62a7972344d1a8eec5de8a21130a19272738bce1135871d8bab098585a841"),
    ("weights/weight.bin", 30040968, "ad460549f68898eab7fe946e9675efaa2551d37b93f73796958c73d4881897fc")
  ]
  static func install(in root: URL, progress: @escaping @Sendable (String, Double) -> Void) async throws -> URL {
    let folder = root.appendingPathComponent("Separator.mlmodelc", isDirectory: true)
    let config = URLSessionConfiguration.ephemeral; config.httpCookieStorage = nil
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    // The manifest has five files, not five separate setup phases. Fetch them
    // together only after the user asks for Sing Along; verify every byte.
    progress("Installing Sing Along model (31 MB, once)", 0)
    try await withThrowingTaskGroup(of: Void.self) { group in
      for entry in files {
        group.addTask {
          try Task.checkCancellation()
          let destination = folder.appendingPathComponent(entry.0)
          if let data = try? Data(contentsOf: destination), data.count == entry.1,
            SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == entry.2 { return }
          let remote = URL(string: "https://huggingface.co/My-Name-Is-Jeff/vitrine-sing/resolve/\(revision)/separator-light.mlmodelc/\(entry.0)")!
          var request = URLRequest(url: remote); request.timeoutInterval = 120
          let (temporary, response) = try await session.download(for: request)
          defer { try? FileManager.default.removeItem(at: temporary) }
          guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw MusynSingError.failed("Vocal model download unavailable") }
          let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize
          guard size == entry.1 else { throw MusynSingError.failed("Vocal model size did not match") }
          let data = try Data(contentsOf: temporary)
          guard data.count == entry.1, SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == entry.2 else { throw MusynSingError.failed("Vocal model checksum did not match") }
          try Task.checkCancellation()
          try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
          try data.write(to: destination, options: .atomic)
        }
      }
      var complete = 0
      for try await _ in group {
        complete += 1
        progress("Installing Sing Along model (31 MB, once)", Double(complete) / Double(files.count))
      }
    }
    return folder
  }
}

/// Real source separation, prepared off the audio render thread. No audio upload.
@available(iOS 18.0, macOS 15.0, *)
enum MusynSingEngine {
  static let rate = 44100.0
  static func prepare(input: URL, output: URL, model: URL, progress: @escaping @Sendable (String, Double) -> Void) async throws -> URL {
    if await validCache(output) { return output }
    try? FileManager.default.removeItem(at: output)
    let scratch = output.deletingPathExtension().appendingPathExtension("pcm.caf")
    let partial = output.deletingPathExtension().appendingPathExtension("partial.mov")
    defer { try? FileManager.default.removeItem(at: scratch); try? FileManager.default.removeItem(at: partial) }
    progress("Reading audio", 0)
    try await decode(input, to: scratch)
    try Task.checkCancellation()
    let audio = try AVAudioFile(forReading: scratch, commonFormat: .pcmFormatFloat32, interleaved: true)
    guard audio.length > 0, Double(audio.length) / rate <= 900 else { throw MusynSingError.failed("Vocal reduction supports tracks up to 15 minutes") }
    progress("Loading vocal separator", 0)
    let configuration = MLModelConfiguration(); configuration.computeUnits = .all
    let separator = try await MLModel.load(contentsOf: model, configuration: configuration)
    guard separator.modelDescription.inputDescriptionsByName["spectrum"]?.multiArrayConstraint?.shape.map(\.intValue) == MusynVocalDSP.shape,
      separator.modelDescription.outputDescriptionsByName["vocals_spectrum"] != nil else { throw MusynSingError.failed("Unsupported vocal model") }
    let dsp = try MusynVocalDSP()
    try? FileManager.default.removeItem(at: partial)
    let writer = try AVAssetWriter(outputURL: partial, fileType: .mov)
    let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192000]
    let music = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
    let vocals = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
    guard writer.canAdd(music), writer.canAdd(vocals) else { throw MusynSingError.failed("Stem encoder unavailable") }
    writer.add(music); writer.add(vocals)
    guard writer.startWriting() else { throw writer.error ?? MusynSingError.failed("Stem encoder failed") }
    writer.startSession(atSourceTime: .zero)
    let step = 66150, overlap = MusynVocalDSP.frames - step
    var previous = [Float]()
    var position: AVAudioFramePosition = 0
    do {
      while position < audio.length {
        try Task.checkCancellation()
        if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue { throw MusynSingError.failed("The phone is too warm; try vocal reduction later") }
        audio.framePosition = position
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: AVAudioFrameCount(MusynVocalDSP.frames)) else { throw MusynSingError.failed("Audio buffer unavailable") }
        try audio.read(into: buffer)
        let count = Int(buffer.frameLength)
        guard let source = buffer.floatChannelData?[0], count > 0 else { throw MusynSingError.failed("Invalid decoded audio") }
        var original = [Float](repeating: 0, count: MusynVocalDSP.frames * 2)
        original.withUnsafeMutableBufferPointer { $0.baseAddress!.update(from: source, count: count * 2) }
        let tensor = try dsp.encode(original)
        let features = try MLDictionaryFeatureProvider(dictionary: ["spectrum": tensor])
        let prediction = try await separator.prediction(from: features)
        guard let spectrum = prediction.featureValue(for: "vocals_spectrum")?.multiArrayValue else { throw MusynSingError.failed("Vocal prediction unavailable") }
        var voice = try dsp.decode(spectrum)
        if !previous.isEmpty {
          for frame in 0..<min(overlap, count) {
            let fraction = Float(frame) / Float(overlap)
            for channel in 0..<2 { let i = frame * 2 + channel; voice[i] = previous[i] * (1 - fraction) + voice[i] * fraction }
          }
        }
        previous = Array(voice[(step * 2)...])
        let emit = min(step, count)
        var background = [Float](repeating: 0, count: emit * 2)
        for i in 0..<background.count { background[i] = original[i] - voice[i] }
        // Shared headroom preserves relative stem balance and avoids hard clipping.
        for i in 0..<background.count { background[i] *= 0.85; voice[i] *= 0.85 }
        try await append(Array(voice.prefix(emit * 2)), to: vocals, at: position, writer: writer)
        try await append(background, to: music, at: position, writer: writer)
        position += AVAudioFramePosition(emit)
        progress("Separating vocals on this device", Double(position) / Double(audio.length))
      }
      music.markAsFinished(); vocals.markAsFinished()
      await writer.finishWriting()
      guard writer.status == .completed else { throw writer.error ?? MusynSingError.failed("Stem export failed") }
      try Task.checkCancellation()
      try FileManager.default.moveItem(at: partial, to: output)
      progress("Ready", 1)
      return output
    } catch { writer.cancelWriting(); throw error }
  }
  static func validCache(_ url: URL) async -> Bool {
    guard FileManager.default.fileExists(atPath: url.path) else { return false }
    let asset = AVURLAsset(url: url)
    guard let tracks = try? await asset.loadTracks(withMediaType: .audio), tracks.count == 2,
      let duration = try? await asset.load(.duration), duration.seconds.isFinite, duration.seconds > 0, duration.seconds <= 901 else { return false }
    return true
  }
  private static func decode(_ input: URL, to output: URL) async throws {
    let asset = AVURLAsset(url: input)
    let duration = try await asset.load(.duration)
    guard duration.seconds.isFinite, duration.seconds > 0, duration.seconds <= 900 else { throw MusynSingError.failed("Vocal reduction needs a finite track up to 15 minutes") }
    let tracks = try await asset.loadTracks(withMediaType: .audio)
    guard !tracks.isEmpty else { throw MusynSingError.failed("No audio track") }
    let reader = try AVAssetReader(asset: asset)
    let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 2,
      AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false]
    let source = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: settings)
    reader.add(source)
    let file = try AVAudioFile(forWriting: output, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: true)
    guard reader.startReading() else { throw reader.error ?? MusynSingError.failed("Audio reader failed") }
    while let sample = source.copyNextSampleBuffer() {
      try Task.checkCancellation()
      guard let data = CMSampleBufferGetDataBuffer(sample) else { throw MusynSingError.failed("Audio data unavailable") }
      let frames = CMSampleBufferGetNumSamples(sample)
      guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(frames)), let pointer = buffer.floatChannelData?[0] else { throw MusynSingError.failed("Audio buffer unavailable") }
      buffer.frameLength = AVAudioFrameCount(frames)
      guard CMBlockBufferGetDataLength(data) == frames * 8, CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: frames * 8, destination: pointer) == kCMBlockBufferNoErr else { throw MusynSingError.failed("Audio format changed") }
      try file.write(from: buffer)
    }
    guard reader.status == .completed else { throw reader.error ?? MusynSingError.failed("Audio decode failed") }
  }
  private static func append(_ pcm: [Float], to input: AVAssetWriterInput, at position: AVAudioFramePosition, writer: AVAssetWriter) async throws {
    while !input.isReadyForMoreMediaData {
      try Task.checkCancellation()
      guard writer.status == .writing else { throw writer.error ?? MusynSingError.failed("Stem encoder stopped") }
      try await Task.sleep(nanoseconds: 1_000_000)
    }
    var description: CMAudioFormatDescription?
    var format = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
      mBytesPerPacket: 8, mFramesPerPacket: 1, mBytesPerFrame: 8, mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
    guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &format, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &description) == noErr else { throw MusynSingError.failed("Audio description failed") }
    var block: CMBlockBuffer?
    let bytes = pcm.count * MemoryLayout<Float>.size
    guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: bytes, blockAllocator: kCFAllocatorDefault,
      customBlockSource: nil, offsetToData: 0, dataLength: bytes, flags: 0, blockBufferOut: &block) == noErr, let block = block else { throw MusynSingError.failed("Audio block unavailable") }
    let copied = pcm.withUnsafeBytes { CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes) }
    guard copied == noErr else { throw MusynSingError.failed("Audio copy failed") }
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 44100), presentationTimeStamp: CMTime(value: position, timescale: 44100), decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    var frameSize = 8
    guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: description,
      sampleCount: pcm.count / 2, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
      sampleSizeEntryCount: 1, sampleSizeArray: &frameSize, sampleBufferOut: &sample) == noErr, let sample = sample, input.append(sample) else { throw writer.error ?? MusynSingError.failed("Stem encoder rejected audio") }
  }
}
