import Flutter
import UIKit
import MediaPlayer
import AVKit
import AVFoundation
import ImageIO
import Security

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let motion = MusynMotionArtwork()
  private var motionChannel: FlutterMethodChannel?
  private var favoritesChannel: FlutterMethodChannel?
  private var providerChannel: FlutterMethodChannel?
  private var linksChannel: FlutterMethodChannel?
  private var artworkChannel: FlutterMethodChannel?
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
    let covers = FlutterMethodChannel(
      name: "com.vorynlabs.musyn/artwork", binaryMessenger: registrar.messenger())
    artworkChannel = covers
    covers.setMethodCallHandler { call, result in
      guard call.method == "squareCover", let args = call.arguments as? [String: Any],
        let bytes = args["bytes"] as? FlutterStandardTypedData else {
        result(FlutterMethodNotImplemented); return
      }
      let video = args["videoThumbnail"] as? Bool ?? false
      let minimumWidth = args["minimumWidth"] as? Int ?? 0
      DispatchQueue.global(qos: .utility).async {
        let png = MusynSquareCover.make(bytes.data, video: video, minimumWidth: minimumWidth)
        DispatchQueue.main.async { result(png.map { FlutterStandardTypedData(bytes: $0) }) }
      }
    }
    let access = FlutterMethodChannel(name: "com.vorynlabs.musyn/provider_access", binaryMessenger: registrar.messenger())
    providerChannel = access
    access.setMethodCallHandler { call, result in
      let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.vorynlabs.musyn.provider", kSecAttrAccount as String: "jiosaavn"]
      switch call.method {
      case "read":
        var read = query; read[kSecReturnData as String] = true
        var item: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &item)
        if status == errSecItemNotFound { result(nil) }
        else if status == errSecSuccess, let data = item as? Data { result(String(data: data, encoding: .utf8)) }
        else { result(FlutterError(code: "keychain", message: "Keychain is unavailable", details: nil)) }
      case "write":
        guard let args = call.arguments as? [String: Any], let value = args["value"] as? String,
          let data = value.data(using: .utf8), data.count == 8 else {
          result(FlutterError(code: "format", message: "Expected an 8-byte media URL key", details: nil)); return
        }
        let changes: [String: Any] = [kSecValueData as String: data,
          kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound { status = SecItemAdd(query.merging(changes) { _, new in new } as CFDictionary, nil) }
        result(status == errSecSuccess ? nil : FlutterError(code: "keychain", message: "Key could not be saved", details: nil))
      case "delete":
        let status = SecItemDelete(query as CFDictionary)
        result(status == errSecSuccess || status == errSecItemNotFound ? nil : FlutterError(code: "keychain", message: "Key could not be removed", details: nil))
      default: result(FlutterMethodNotImplemented)
      }
    }
    let links = FlutterMethodChannel(name: "com.vorynlabs.musyn/links", binaryMessenger: registrar.messenger())
    linksChannel = links
    links.setMethodCallHandler { call, result in
      guard call.method == "open", let value = call.arguments as? String, let url = URL(string: value), url.scheme == "https" else {
        result(FlutterMethodNotImplemented); return
      }
      UIApplication.shared.open(url, options: [:]) { result($0) }
    }
    registrar.register(MusynGlassFactory(), withId: "com.vorynlabs.musyn/glass")
    registrar.register(MusynClipFactory(messenger: registrar.messenger()), withId: "com.vorynlabs.musyn/clip")
    let motionChannel = FlutterMethodChannel(name: "com.vorynlabs.musyn/motion", binaryMessenger: registrar.messenger())
    self.motionChannel = motionChannel
    motionChannel.setMethodCallHandler { call, result in
      if call.method == "supported" {
        if #available(iOS 26.0, *) { result(true) } else { result(false) }
      } else if call.method == "validate", let path = call.arguments as? String {
        Task {
          let valid = await MusynClipValidation.valid(URL(fileURLWithPath: path))
          await MainActor.run { result(valid) }
        }
      } else { result(FlutterMethodNotImplemented) }
    }
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
      self?.motion.update(mediaID: state["mediaId"] as? String,
        path: state["motionPath"] as? String, enabled: state["motionEnabled"] as? Bool ?? false)
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

/// Native square preparation does not depend on a foreground Flutter rasterizer.
private enum MusynSquareCover {
  static func make(_ data: Data, video: Bool, minimumWidth: Int) -> Data? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 1440
      ] as CFDictionary) else { return nil }
    guard image.width >= minimumWidth else { return nil }
    let width = CGFloat(image.width), height = CGFloat(image.height)
    let contentHeight = video ? min(height, width * 9 / 16) : height
    let side = min(width, contentHeight)
    guard let cropped = image.cropping(to: CGRect(
      x: (width - side) / 2, y: (height - side) / 2, width: side, height: side)) else { return nil }
    let size = min(Int(side), 1024)
    guard let context = CGContext(data: nil, width: size, height: size,
      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.interpolationQuality = .high
    context.draw(cropped, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let square = context.makeImage(),
      let output = CFDataCreateMutable(nil, 0),
      let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil)
      else { return nil }
    CGImageDestinationAddImage(destination, square, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return output as Data
  }
}

private enum MusynClipValidation {
  static func valid(_ url: URL) async -> Bool {
    let asset = AVURLAsset(url: url)
    guard let playable = try? await asset.load(.isPlayable), playable,
      let duration = try? await asset.load(.duration), duration.seconds >= 0.5, duration.seconds <= 30,
      let tracks = try? await asset.loadTracks(withMediaType: .video), let track = tracks.first,
      let audio = try? await asset.loadTracks(withMediaType: .audio), audio.isEmpty,
      let size = try? await track.load(.naturalSize), let transform = try? await track.load(.preferredTransform) else { return false }
    let bounds = CGRect(origin: .zero, size: size).applying(transform)
    let ratio = abs(bounds.width / bounds.height)
    return abs(ratio - 1) < 0.03 || abs(ratio - 0.75) < 0.03
  }
}
private final class MusynGlassFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    MusynGlassView(frame: frame, radius: (args as? [String: Any])?["radius"] as? CGFloat ?? 18, dark: (args as? [String: Any])?["dark"] as? Bool ?? true)
  }
}
private final class MusynGlassView: NSObject, FlutterPlatformView {
  private let surface: UIVisualEffectView
  init(frame: CGRect, radius: CGFloat, dark: Bool) {
    if #available(iOS 26.0, *) { surface = UIVisualEffectView(effect: UIGlassEffect(style: .regular)) }
    else { surface = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial)) }
    super.init()
    surface.overrideUserInterfaceStyle = dark ? .dark : .light
    surface.frame = frame; surface.layer.cornerRadius = radius; surface.clipsToBounds = true
    surface.isUserInteractionEnabled = false
  }
  func view() -> UIView { surface }
}
private final class MusynClipFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    MusynClipView(frame: frame, id: viewId, args: args as? [String: Any] ?? [:], messenger: messenger)
  }
}
private final class MusynVideoSurface: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }
}
private final class MusynClipView: NSObject, FlutterPlatformView {
  let surface = MusynVideoSurface()
  let player = AVQueuePlayer()
  var looper: AVPlayerLooper?
  let channel: FlutterMethodChannel
  var observers: [NSObjectProtocol] = []
  var wantsPlayback: Bool
  init(frame: CGRect, id: Int64, args: [String: Any], messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.vorynlabs.musyn/clip/\(id)", binaryMessenger: messenger)
    wantsPlayback = args["playing"] as? Bool ?? false
    super.init()
    surface.frame = frame; surface.backgroundColor = .clear
    if let path = args["path"] as? String {
      looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: URL(fileURLWithPath: path)))
    }
    player.isMuted = true
    (surface.layer as? AVPlayerLayer)?.player = player
    (surface.layer as? AVPlayerLayer)?.videoGravity = .resizeAspectFill
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "playing", let playing = call.arguments as? Bool else { result(FlutterMethodNotImplemented); return }
      self?.wantsPlayback = playing; self?.sync(); result(nil)
    }
    for name in [UIApplication.didEnterBackgroundNotification, UIApplication.didBecomeActiveNotification,
                 UIAccessibility.reduceMotionStatusDidChangeNotification, NSNotification.Name.NSProcessInfoPowerStateDidChange] {
      observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.sync() })
    }
    sync()
  }
  func sync() {
    if wantsPlayback && UIApplication.shared.applicationState == .active && !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled { player.play() }
    else { player.pause() }
  }
  deinit { observers.forEach { NotificationCenter.default.removeObserver($0) }; player.pause(); channel.setMethodCallHandler(nil) }
  func view() -> UIView { surface }
}

/// Enrich only the exact item audio_service just published; never replace its timeline.
private final class MusynMotionArtwork {
  private var observer: NSObjectProtocol?
  private var mediaID: String?
  private var publishedID: String?
  private var path: String?
  private var enabled = false
  private var artwork: Any?
  private var portrait = false
  init() {
    observer = NotificationCenter.default.addObserver(forName: NSNotification.Name("MusynNowPlayingInfoUpdated"), object: nil, queue: .main) { [weak self] note in
      self?.publishedID = note.userInfo?["mediaId"] as? String
      self?.apply()
    }
  }
  deinit { if let observer = observer { NotificationCenter.default.removeObserver(observer) } }
  func update(mediaID: String?, path: String?, enabled: Bool) {
    let changed = self.path != path || self.mediaID != mediaID || self.enabled != enabled
    self.mediaID = mediaID; self.path = path; self.enabled = enabled
    if changed {
      artwork = nil
      if enabled, let path = path, let mediaID = mediaID {
        let url = URL(fileURLWithPath: path)
        Task { [weak self] in
          guard await MusynClipValidation.valid(url) else { return }
          DispatchQueue.global(qos: .utility).async { [weak self] in
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url)); generator.appliesPreferredTrackTransform = true
            guard let image = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return }
            DispatchQueue.main.async { [weak self] in
              guard let self = self, self.enabled, self.mediaID == mediaID, self.path == path else { return }
              self.install(UIImage(cgImage: image), url: url)
            }
          }
        }
      }
    }
    apply()
  }
  private func install(_ preview: UIImage, url: URL) {
    if #available(iOS 26.0, *) {
      portrait = preview.size.width / preview.size.height < 0.9
      artwork = MPMediaItemAnimatedArtwork(artworkID: url.lastPathComponent,
        previewImageRequestHandler: { _ in preview }, videoAssetFileURLRequestHandler: { _ in
          let allowed = await MainActor.run { !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled }
          return allowed && FileManager.default.fileExists(atPath: url.path) ? url : nil
        })
      apply()
    }
  }
  private func apply() {
    if #available(iOS 26.0, *) {
      guard let mediaID = mediaID, mediaID == publishedID, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
      info.removeValue(forKey: MPNowPlayingInfoProperty1x1AnimatedArtwork)
      info.removeValue(forKey: MPNowPlayingInfoProperty3x4AnimatedArtwork)
      let key = portrait ? MPNowPlayingInfoProperty3x4AnimatedArtwork : MPNowPlayingInfoProperty1x1AnimatedArtwork
      if enabled, let artwork = artwork, MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys.contains(key) { info[key] = artwork }
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
  }
}
