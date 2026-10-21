import Foundation
import Accelerate
import CoreML

/// Independent STFT adapter for the public separator's documented tensor contract.
/// 44.1 kHz stereo, 2-second windows; real/imaginary bins for each channel.
final class MusynVocalDSP {
  static let frames = 88200, fft = 2048, hop = 441, columns = 201, bins = 1025
  static let shape = [1, 2050, 201, 2]
  private let forward: vDSP_DFT_Setup
  private let inverse: vDSP_DFT_Setup
  private let window: [Float]
  private var real = [Float](repeating: 0, count: fft)
  private var imag = [Float](repeating: 0, count: fft)
  private var outReal = [Float](repeating: 0, count: fft)
  private var outImag = [Float](repeating: 0, count: fft)
  init() throws {
    guard let f = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.fft), .FORWARD),
          let i = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.fft), .INVERSE) else { throw MusynSingError.failed("Audio transform unavailable") }
    forward = f; inverse = i
    window = (0..<Self.fft).map { Float(0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(Self.fft))) }
  }
  deinit { vDSP_DFT_DestroySetup(forward); vDSP_DFT_DestroySetup(inverse) }
  func encode(_ pcm: [Float]) throws -> MLMultiArray {
    guard pcm.count == Self.frames * 2, pcm.allSatisfy(\.isFinite) else { throw MusynSingError.failed("Invalid audio samples") }
    let tensor = try MLMultiArray(shape: Self.shape.map(NSNumber.init), dataType: .float32)
    let target = tensor.dataPointer.assumingMemoryBound(to: Float.self)
    let strides = tensor.strides.map(\.intValue)
    for channel in 0..<2 {
      for frame in 0..<Self.columns {
        for n in 0..<Self.fft {
          let p = frame * Self.hop + n - Self.fft / 2
          let source = p < 0 ? -p : p >= Self.frames ? 2 * Self.frames - p - 2 : p
          real[n] = pcm[source * 2 + channel] * window[n]; imag[n] = 0
        }
        vDSP_DFT_Execute(forward, real, imag, &outReal, &outImag)
        for bin in 0..<Self.bins {
          let offset = (bin * 2 + channel) * strides[1] + frame * strides[2]
          target[offset] = outReal[bin]; target[offset + strides[3]] = outImag[bin]
        }
      }
    }
    return tensor
  }
  func decode(_ tensor: MLMultiArray) throws -> [Float] {
    guard tensor.shape.map(\.intValue) == Self.shape, tensor.dataType == .float32 || tensor.dataType == .float16 else { throw MusynSingError.failed("Unexpected separator output") }
    let strides = tensor.strides.map(\.intValue)
    func value(_ index: Int) -> Float {
      tensor.dataType == .float32 ? tensor.dataPointer.assumingMemoryBound(to: Float.self)[index] : Float(tensor.dataPointer.assumingMemoryBound(to: Float16.self)[index])
    }
    var pcm = [Float](repeating: 0, count: Self.frames * 2)
    for channel in 0..<2 {
      var sum = [Float](repeating: 0, count: Self.frames + Self.fft)
      var weight = sum
      for frame in 0..<Self.columns {
        for bin in 0..<Self.bins {
          let offset = (bin * 2 + channel) * strides[1] + frame * strides[2]
          real[bin] = value(offset); imag[bin] = value(offset + strides[3])
          if bin > 0 && bin < Self.fft / 2 { real[Self.fft - bin] = real[bin]; imag[Self.fft - bin] = -imag[bin] }
        }
        imag[0] = 0; imag[Self.fft / 2] = 0
        vDSP_DFT_Execute(inverse, real, imag, &outReal, &outImag)
        for n in 0..<Self.fft {
          let index = frame * Self.hop + n
          sum[index] += outReal[n] * window[n] / Float(Self.fft)
          weight[index] += window[n] * window[n]
        }
      }
      for n in 0..<Self.frames { pcm[n * 2 + channel] = sum[n + Self.fft / 2] / max(weight[n + Self.fft / 2], 1e-8) }
    }
    guard pcm.allSatisfy(\.isFinite) else { throw MusynSingError.failed("Nonfinite separator output") }
    return pcm
  }
}
