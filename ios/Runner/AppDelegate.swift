import Flutter
import UIKit
import MediaPlayer
import AVKit
import AVFoundation
import CoreImage
import CryptoKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let systemArtwork = MusynSystemArtwork()
  private var favoritesChannel: FlutterMethodChannel?
  private var favoriteTarget: Any?
  private var favoriteTrackID: String?
  private var favoriteRequestInFlight = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // AVAudioSession is configured in Dart via audio_session to avoid fighting
    // MPRemoteCommandCenter / lock-screen controls.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MusynRemoteFavorites") else { return }
    registrar.register(MusynAudioRouteFactory(), withId: "com.vorynlabs.musyn/audio_route")
    let channel = FlutterMethodChannel(
      name: "com.vorynlabs.musyn/remote_favorites", binaryMessenger: registrar.messenger())
    favoritesChannel = channel
    let favorite = MPRemoteCommandCenter.shared().likeCommand
    favorite.localizedTitle = "Favorite"
    favorite.localizedShortTitle = "Favorite"
    if let target = favoriteTarget { favorite.removeTarget(target) }
    favorite.isEnabled = false
    favoriteTarget = favorite.addTarget { [weak self] _ in
      let action: () -> MPRemoteCommandHandlerStatus = {
        guard let self = self, let id = self.favoriteTrackID,
          !self.favoriteRequestInFlight else { return .commandFailed }
        self.favoriteRequestInFlight = true
        let selected = !favorite.isActive
        channel.invokeMethod("setFavorite", arguments: ["trackId": id, "liked": selected]) { result in
          self.favoriteRequestInFlight = false
          if self.favoriteTrackID == id, let accepted = result as? Bool, accepted {
            favorite.isActive = selected
          }
        }
        return .success
      }
      // Platform channels and feedback state are owned by the main thread.
      return Thread.isMainThread ? action() : DispatchQueue.main.sync(execute: action)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setState", let state = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.systemArtwork.update(mediaID: state["mediaId"] as? String, artworkURI: state["artUri"] as? String)
      self?.favoriteTrackID = state["trackId"] as? String
      favorite.isActive = state["liked"] as? Bool ?? false
      favorite.isEnabled = self?.favoriteTrackID != nil
      result(nil)
    }
  }
}

private final class MusynAudioRouteFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let dark = (args as? [String: Any])?["dark"] as? Bool ?? true
    return MusynAudioRouteView(frame: frame, dark: dark)
  }
}

private final class MusynAudioRouteView: NSObject, FlutterPlatformView {
  private let picker: AVRoutePickerView
  init(frame: CGRect, dark: Bool) {
    picker = AVRoutePickerView(frame: frame)
    super.init()
    picker.tintColor = dark ? .white : .black
    picker.activeTintColor = .systemPink
    picker.backgroundColor = .clear
    picker.prioritizesVideoDevices = false
    picker.accessibilityLabel = "Audio output"
  }
  func view() -> UIView { picker }
}

/// The audio plugin owns the timeline. This observer adds only artwork after
/// its metadata update, guarded by the exact queue entry ID.
private final class MusynSystemArtwork {
  private var observer: NSObjectProtocol?
  private var mediaID: String?
  private var publishedID: String?
  private var artworkURI: String?
  private var animatedArtwork: [String: Any] = [:]

  init() {
    observer = NotificationCenter.default.addObserver(
      forName: NSNotification.Name("MusynNowPlayingInfoUpdated"), object: nil, queue: .main
    ) { [weak self] note in
      self?.publishedID = note.userInfo?["mediaId"] as? String
      self?.apply()
    }
  }
  deinit { if let observer = observer { NotificationCenter.default.removeObserver(observer) } }

  func update(mediaID: String?, artworkURI: String?) {
    if self.mediaID != mediaID || self.artworkURI != artworkURI {
      animatedArtwork.removeAll()
      self.mediaID = mediaID
      self.artworkURI = artworkURI
    }
    apply()
  }

  private func apply() {
    // SDK guards retain compatibility with older Xcode and older iOS builds.
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      guard let mediaID = mediaID, mediaID == publishedID,
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
      let keys = MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys
      let variants = [(MPNowPlayingInfoProperty1x1AnimatedArtwork, false), (MPNowPlayingInfoProperty3x4AnimatedArtwork, true)]
      guard let uri = artworkURI, let url = URL(string: uri), url.isFileURL else {
        var changed = false
        for (key, _) in variants { if info.removeValue(forKey: key) != nil { changed = true } }
        if changed { MPNowPlayingInfoCenter.default().nowPlayingInfo = info }
        return
      }
      for (key, tall) in variants where keys.contains(key) {
        if animatedArtwork[key] == nil {
          guard let image = UIImage(contentsOfFile: url.path) else { continue }
          let preview = MusynArtworkMovie.preview(image, tall: tall)
          animatedArtwork[key] = MPMediaItemAnimatedArtwork(
            artworkID: uri + (tall ? "-3x4" : "-1x1"),
            previewImageRequestHandler: { _ in preview },
            videoAssetFileURLRequestHandler: { _ in
              let shouldAnimate = await MainActor.run {
                !ProcessInfo.processInfo.isLowPowerModeEnabled && !UIAccessibility.isReduceMotionEnabled
              }
              guard shouldAnimate else { return nil }
              return await MusynArtworkMovie.make(from: url, tall: tall)
            }
          )
        }
        info[key] = animatedArtwork[key]
      }
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    #endif
  }
}

/// Small, silent, seamless artwork loops are generated only when iOS requests
/// the visible asset. Encoding never runs on the UI or audio threads.
private enum MusynArtworkMovie {
  private static let queue = DispatchQueue(label: "com.vorynlabs.musyn.artwork", qos: .utility)
  static func preview(_ image: UIImage, tall: Bool) -> UIImage {
    guard tall else { return image }
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800), format: format).image { context in
      UIColor.black.setFill(); context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
      image.draw(in: CGRect(x: -100, y: 0, width: 800, height: 800), blendMode: .normal, alpha: 0.4)
      image.draw(in: CGRect(x: 20, y: 120, width: 560, height: 560))
    }
  }
  static func make(from imageURL: URL, tall: Bool) async -> URL? {
    await withCheckedContinuation { continuation in
      queue.async { continuation.resume(returning: encode(imageURL, tall: tall)) }
    }
  }
  private static func encode(_ imageURL: URL, tall: Bool) -> URL? {
    let files = FileManager.default
    guard let cache = files.urls(for: .cachesDirectory, in: .userDomainMask).first,
      let image = UIImage(contentsOfFile: imageURL.path)?.cgImage else { return nil }
    let folder = cache.appendingPathComponent("MusynAnimatedArtwork", isDirectory: true)
    try? files.createDirectory(at: folder, withIntermediateDirectories: true)
    let key = SHA256.hash(data: Data((imageURL.path + (tall ? "-3x4" : "-1x1")).utf8)).map { String(format: "%02x", $0) }.joined()
    let output = folder.appendingPathComponent(key + ".mp4")
    if files.fileExists(atPath: output.path) { return output }
    let temporary = folder.appendingPathComponent(key + ".partial.mp4")
    try? files.removeItem(at: temporary)
    guard let writer = try? AVAssetWriter(outputURL: temporary, fileType: .mp4) else { return nil }
    let width = tall ? 600 : 640
    let height = tall ? 800 : 640
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width, AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 750_000],
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
      kCVPixelBufferCGImageCompatibilityKey as String: true,
    ])
    guard writer.canAdd(input) else { return nil }
    writer.add(input)
    guard writer.startWriting() else { return nil }
    writer.startSession(atSourceTime: .zero)
    let context = CIContext(options: [.cacheIntermediates: false])
    let original = CIImage(cgImage: image)
    let bounds = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
    let coverSide: CGFloat = tall ? 560 : 640
    let base = original.transformed(by: CGAffineTransform(
      scaleX: coverSide / original.extent.width, y: coverSide / original.extent.height))
      .transformed(by: CGAffineTransform(translationX: tall ? 20 : 0, y: tall ? 120 : 0))
    let bgScale = max(CGFloat(width) / original.extent.width, CGFloat(height) / original.extent.height)
    let background = original.transformed(by: CGAffineTransform(scaleX: bgScale, y: bgScale))
      .transformed(by: CGAffineTransform(translationX: (CGFloat(width) - original.extent.width * bgScale) / 2,
        y: (CGFloat(height) - original.extent.height * bgScale) / 2))
    let dimmed = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.6)).cropped(to: bounds).composited(over: background)
    let cx = CGFloat(width) / 2; let cy = CGFloat(height) / 2
    let frameCount = 192 // Eight seconds at 24 fps.
    let deadline = Date().addingTimeInterval(18)
    var success = true
    for frame in 0..<frameCount {
      while !input.isReadyForMoreMediaData && writer.status == .writing && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.002)
      }
      guard Date() < deadline, writer.status == .writing,
        let pool = adaptor.pixelBufferPool else { success = false; break }
      var buffer: CVPixelBuffer?
      guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
        let buffer = buffer else { success = false; break }
      let phase = Double(frame) / Double(frameCount) * .pi * 2
      let scale = 1.045 + sin(phase) * 0.008
      let transform = CGAffineTransform(translationX: -cx, y: -cy)
        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        .concatenating(CGAffineTransform(rotationAngle: sin(phase) * 0.012))
        .concatenating(CGAffineTransform(translationX: cx + sin(phase) * 3, y: cy + cos(phase) * 3))
      context.render(base.transformed(by: transform).composited(over: dimmed), to: buffer,
        bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
      if !adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 24)) {
        success = false; break
      }
    }
    guard success else { writer.cancelWriting(); try? files.removeItem(at: temporary); return nil }
    input.markAsFinished()
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    guard finished.wait(timeout: .now() + 5) == .success, writer.status == .completed else {
      writer.cancelWriting(); try? files.removeItem(at: temporary); return nil
    }
    do { try files.moveItem(at: temporary, to: output) } catch { return nil }
    // A bounded cache; retain the active movie for as long as it is published.
    let movies = (try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    let oldest = movies.filter { $0.pathExtension == "mp4" && $0 != output }
      .sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
        < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
    for stale in oldest.prefix(max(0, oldest.count - 7)) { try? files.removeItem(at: stale) }
    return output
  }
}
