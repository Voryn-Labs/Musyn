// Executed against the production MusynSquareCover type by test_native_artwork.py.
func png(_ image: CGImage) -> Data {
  let output = CFDataCreateMutable(nil, 0)!
  let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, image, nil)
  precondition(CGImageDestinationFinalize(destination))
  return output as Data
}
func context(_ width: Int, _ height: Int) -> CGContext {
  CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
}
let fixture = context(480, 360)
fixture.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
fixture.fill(CGRect(x: 0, y: 0, width: 480, height: 360))
fixture.setFillColor(CGColor(red: 1, green: 0, blue: 0.4, alpha: 1))
fixture.fill(CGRect(x: 0, y: 45, width: 480, height: 270))
let input = png(fixture.makeImage()!)
let output = MusynSquareCover.make(input, video: true, minimumWidth: 480)!
let source = CGImageSourceCreateWithData(output as CFData, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
precondition(image.width == 270 && image.height == 270, "Video letterbox crop dimensions")
let result = context(270, 270)
result.draw(image, in: CGRect(x: 0, y: 0, width: 270, height: 270))
let pixels = result.data!.assumingMemoryBound(to: UInt8.self)
for pixel in [0, 269, 270 * 269, 270 * 270 - 1, 270 * 135 + 135] {
  precondition(pixels[pixel * 4] > 245, "Black letterbox pixel in square")
  for channel in 0..<4 {
    precondition(abs(Int(pixels[pixel * 4 + channel]) - Int(pixels[(270 * 135 + 135) * 4 + channel])) <= 2,
      "Crop edge differs from the solid center")
  }
}
precondition(MusynSquareCover.make(input, video: true, minimumWidth: 1000) == nil,
  "Tiny maxres placeholders must fall back")
precondition(MusynSquareCover.make(Data([0, 1, 2]), video: false, minimumWidth: 0) == nil,
  "Invalid image data must fail safely")
print("Native cover tests passed: dimensions, letterbox edges, placeholder fallback, invalid input")
