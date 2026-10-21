import Foundation
import CoreGraphics
import CoreText
import AVFoundation

/// A lyric poster and a tiny silent video for the public Now Playing artwork API.
/// Text follows real line timestamps; the artwork does not invent word timing.
enum MusynLyricArtwork {
  static func poster(current: String, next: String?, width: Int = 720, height: Int = 960) throws -> CGImage {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw MusynSingError.failed("Lyric artwork unavailable") }
    let w = CGFloat(width), h = CGFloat(height)
    context.setFillColor(CGColor(red: 0.055, green: 0.045, blue: 0.065, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: w, height: h))
    let pink = CGColor(red: 1, green: 0.56, blue: 0.69, alpha: 1)
    draw("LIVE LYRICS", in: CGRect(x: 56, y: h - 140, width: w - 112, height: 40), size: 18,
      color: CGColor(gray: 0.55, alpha: 1), context: context)
    draw(current, in: CGRect(x: 52, y: h * 0.32, width: w - 104, height: h * 0.40), size: 60, color: pink, context: context)
    if let next = next, !next.isEmpty {
      draw(next, in: CGRect(x: 64, y: h * 0.12, width: w - 128, height: h * 0.16), size: 32,
        color: CGColor(gray: 0.55, alpha: 1), context: context)
    }
    guard let image = context.makeImage() else { throw MusynSingError.failed("Lyric poster unavailable") }
    return image
  }
  private static func draw(_ text: String, in rect: CGRect, size: CGFloat, color: CGColor, context: CGContext) {
    var point = size
    var rows: [CTLine] = []
    while point >= min(24, size) {
      let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, point, nil)
      let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color])
      let setter = CTTypesetterCreateWithAttributedString(attributed)
      rows = []; var at = 0
      while at < attributed.length && rows.count < 12 {
        let count = max(1, CTTypesetterSuggestLineBreak(setter, at, Double(rect.width)))
        rows.append(CTTypesetterCreateLine(setter, CFRange(location: at, length: count))); at += count
      }
      if CGFloat(rows.count) * point * 1.25 <= rect.height { break }
      point -= 4
    }
    var y = rect.midY + CGFloat(rows.count) * point * 1.25 / 2 - point
    for line in rows {
      let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
      context.textPosition = CGPoint(x: rect.midX - width / 2, y: y)
      CTLineDraw(line, context); y -= point * 1.25
    }
  }
  static func clip(image: CGImage, at output: URL) async throws -> URL {
    if FileManager.default.fileExists(atPath: output.path) { return output }
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    let temporary = output.deletingPathExtension().appendingPathExtension("partial.mp4")
    try? FileManager.default.removeItem(at: temporary)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let writer = try AVAssetWriter(outputURL: temporary, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: image.width, AVVideoHeightKey: image.height])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
      kCVPixelBufferWidthKey as String: image.width, kCVPixelBufferHeightKey as String: image.height,
      kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? MusynSingError.failed("Lyric video unavailable") }
    writer.startSession(atSourceTime: .zero)
    do {
      for frame in 0..<2 {
        while !input.isReadyForMoreMediaData {
          try Task.checkCancellation()
          guard writer.status == .writing else { throw writer.error ?? MusynSingError.failed("Lyric encoder stopped") }
          try await Task.sleep(nanoseconds: 2_000_000)
        }
        var pixel: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, image.width, image.height, kCVPixelFormatType_32ARGB, nil, &pixel) == kCVReturnSuccess,
          let pixel = pixel else { throw MusynSingError.failed("Lyric frame unavailable") }
        CVPixelBufferLockBaseAddress(pixel, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: image.width, height: image.height, bitsPerComponent: 8,
          bytesPerRow: CVPixelBufferGetBytesPerRow(pixel), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
          CVPixelBufferUnlockBaseAddress(pixel, []); throw MusynSingError.failed("Lyric frame unavailable")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        CVPixelBufferUnlockBaseAddress(pixel, [])
        guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 1)) else { throw writer.error ?? MusynSingError.failed("Lyric frame rejected") }
      }
      writer.endSession(atSourceTime: CMTime(value: 2, timescale: 1))
      input.markAsFinished(); await writer.finishWriting()
      guard writer.status == .completed else { throw writer.error ?? MusynSingError.failed("Lyric video failed") }
      try Task.checkCancellation()
      try FileManager.default.moveItem(at: temporary, to: output)
      return output
    } catch { writer.cancelWriting(); throw error }
  }
}
