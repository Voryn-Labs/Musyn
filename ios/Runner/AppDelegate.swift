import Flutter
import UIKit
import MediaPlayer
import AVKit
import AVFoundation
import ImageIO
import Security
import CryptoKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // One headless-capable engine serves iPhone and CarPlay, including a launch
  // originating from the car before any iPhone window has been connected.
  let musynEngine = FlutterEngine(name: "musyn", project: nil, allowHeadlessExecution: true)
  private let motion = MusynMotionArtwork()
  private var sing: MusynSingBridge?
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
    musynEngine.run()
    GeneratedPluginRegistrant.register(with: musynEngine)
    configureMusynBridges()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureMusynBridges() {
    guard let registrar = musynEngine.registrar(forPlugin: "MusynRemoteFavorites") else { return }
    MusynCarPlay.shared.configure(messenger: registrar.messenger())
    registrar.register(MusynAudioRouteFactory(), withId: "com.vorynlabs.musyn/audio_route")
    let channel = FlutterMethodChannel(
      name: "com.vorynlabs.musyn/remote_favorites", binaryMessenger: registrar.messenger())
    favoritesChannel = channel
    sing = MusynSingBridge(messenger: registrar.messenger())
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
    registrar.register(MusynPlayerMenuFactory(messenger: registrar.messenger()), withId: "com.vorynlabs.musyn/player_menu")
    registrar.register(MusynGlassFactory(), withId: "com.vorynlabs.musyn/glass")
    registrar.register(MusynClipFactory(messenger: registrar.messenger()), withId: "com.vorynlabs.musyn/clip")
    let motionChannel = FlutterMethodChannel(name: "com.vorynlabs.musyn/motion", binaryMessenger: registrar.messenger())
    self.motionChannel = motionChannel
    motion.onPrepared = { [weak self] in self?.motionChannel?.invokeMethod("prepared", arguments: nil) }
    motionChannel.setMethodCallHandler { [weak self] call, result in
      if call.method == "supported" {
        if #available(iOS 26.0, *) { result(true) } else { result(false) }
      } else if call.method == "retainedPaths" {
        result(self?.motion.retainedPath.map { [$0] } ?? [])
      } else if call.method == "clear" {
        self?.motion.clear()
        result(nil)
      } else if call.method == "diagnostics" {
        result(self?.motion.diagnostics() ?? [:])
      } else if call.method == "lyrics", let args = call.arguments as? [String: Any] {
        self?.motion.updateLyrics(id: args["id"] as? String, rows: args["lines"] as? [[String: Any]] ?? [], enabled: args["enabled"] as? Bool ?? false, artist: args["artist"] as? Bool ?? true, artwork: args["artwork"] as? Bool ?? false)
        result(nil)
      } else if call.method == "canFetch" {
        result(!UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled)
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
// Native glass is decorative here; Flutter owns the accessible controls and
// their state/gesture transitions. Clear glass needs its own legibility layer.
private final class MusynGlassSurface: UIView {
  private let effectView = UIVisualEffectView()
  private let dark: Bool
  private var transparencyObserver: NSObjectProtocol?
  init(frame: CGRect, radius: CGFloat, dark: Bool) {
    self.dark = dark
    super.init(frame: frame)
    overrideUserInterfaceStyle = dark ? .dark : .light
    layer.cornerRadius = radius
    layer.cornerCurve = .continuous
    clipsToBounds = true
    isUserInteractionEnabled = false
    effectView.frame = bounds
    effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(effectView)
    updateMaterial()
    transparencyObserver = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil, queue: .main
    ) { [weak self] _ in self?.updateMaterial() }
  }
  required init?(coder: NSCoder) { nil }
  private func updateMaterial() {
    let solid = UIAccessibility.isReduceTransparencyEnabled
    // Do not allow the regular material's adaptive white fill to wash out
    // Flutter labels. Keep a bounded, appearance-matched base under clear glass.
    backgroundColor = dark
      ? UIColor(white: 0.07, alpha: solid ? 1 : 0.88)
      : UIColor(white: 1, alpha: solid ? 1 : 0.88)
    if solid { effectView.effect = nil }
    else if #available(iOS 26.0, *) { effectView.effect = UIGlassEffect(style: .clear) }
    else { effectView.effect = UIBlurEffect(style: dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight) }
  }
  deinit {
    if let transparencyObserver { NotificationCenter.default.removeObserver(transparencyObserver) }
  }
}
private final class MusynGlassView: NSObject, FlutterPlatformView {
  private let surface: MusynGlassSurface
  init(frame: CGRect, radius: CGFloat, dark: Bool) {
    surface = MusynGlassSurface(frame: frame, radius: radius, dark: dark)
    super.init()
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

/// A single enrichment pass over audio_service's canonical, timestamped snapshot.
private final class MusynMotionArtwork {
  var onPrepared: (() -> Void)?
  private var observers: [NSObjectProtocol] = []
  private var mediaID: String?
  private var publishedID: String?
  private var snapshot: [String: Any]?
  private var snapshotAt = ProcessInfo.processInfo.systemUptime
  private var path: String?
  private var enabled = false
  private var artwork: Any?
  private var artworkPath: String?
  private var portrait = false
  private var preparing = false
  private var failedPath: String?
  private var lyricID: String?
  private var lines: [(Double, String)] = []
  private var lyricsEnabled = false
  private var artistLyrics = true
  private var fullLyrics = false
  private var lyricStatic: MPMediaItemArtwork?
  private var lyricMotion: Any?
  private var lyricPath: String?
  private var lyricArtworkKey: String?
  private var lyricArtworkID: String?
  private var lyricTask: Task<Void, Never>?
  private var lyricTimer: DispatchSourceTimer?
  private var lastLine: String?
  private(set) var retainedPath: String?
  init() {
    observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name("MusynNowPlayingInfoUpdated"), object: nil, queue: .main) { [weak self] note in
      guard let self = self else { return }
      self.publishedID = note.userInfo?["mediaId"] as? String
      self.snapshot = MPNowPlayingInfoCenter.default().nowPlayingInfo
      self.snapshotAt = ProcessInfo.processInfo.systemUptime
      self.apply(); self.syncTimer(); self.prepare()
    })
    observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.failedPath = nil; self?.prepare(); self?.apply() })
  }
  deinit { observers.forEach { NotificationCenter.default.removeObserver($0) }; lyricTimer?.cancel(); lyricTask?.cancel() }
  func update(mediaID: String?, path: String?, enabled: Bool) {
    let changed = self.path != path || self.mediaID != mediaID || self.enabled != enabled
    self.mediaID = mediaID; self.path = path; self.enabled = enabled
    if changed { artwork = nil; artworkPath = nil; preparing = false; failedPath = nil }
    prepare(); apply()
  }
  func updateLyrics(id: String?, rows: [[String: Any]], enabled: Bool, artist: Bool, artwork: Bool) {
    if lyricID != id || fullLyrics != artwork || !enabled {
      lyricTask?.cancel(); lyricTask = nil; lyricArtworkID = nil; lyricStatic = nil; lyricMotion = nil; lyricPath = nil
    }
    lyricID = id; lyricsEnabled = enabled; artistLyrics = artist; fullLyrics = artwork
    lines = rows.prefix(1500).compactMap { row in
      guard let at = row["at"] as? Double, at.isFinite, at >= 0, let text = row["text"] as? String, !text.isEmpty else { return nil }
      return (at / 1000, String(text.prefix(400)))
    }.sorted { $0.0 < $1.0 }
    lastLine = nil; apply(); syncTimer()
  }
  private func prepare() {
    guard enabled, artwork == nil, !preparing, let path = path, failedPath != path, let id = mediaID else { return }
    if #available(iOS 26.0, *) {
      let keys = MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys
      guard !keys.isEmpty else { return } // Retry after the system starts publishing.
      preparing = true
      Task { [weak self] in
        let source = URL(fileURLWithPath: path)
        let prepared = try? await MusynArtworkVariant.prepare(source, keys: keys)
        guard let url = prepared, await MusynClipValidation.valid(url) else {
          DispatchQueue.main.async { [weak self] in if self?.path == path, self?.mediaID == id { self?.preparing = false; self?.failedPath = path } }
          return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
          let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url)); generator.appliesPreferredTrackTransform = true
          let frame = try? generator.copyCGImage(at: .zero, actualTime: nil)
          DispatchQueue.main.async { [weak self] in
            guard let self = self, self.enabled, self.mediaID == id, self.path == path else { return }
            self.preparing = false
            guard let frame = frame else { self.failedPath = path; return }
            self.install(UIImage(cgImage: frame), url: url)
          }
        }
      }
    }
  }
  private func install(_ preview: UIImage, url: URL) {
    if #available(iOS 26.0, *) {
      portrait = preview.size.width / preview.size.height < 0.9
      artworkPath = url.path
      artwork = MPMediaItemAnimatedArtwork(artworkID: url.lastPathComponent,
        previewImageRequestHandler: { _ in preview }, videoAssetFileURLRequestHandler: { _ in
          let allowed = await MainActor.run { !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled }
          return allowed && FileManager.default.fileExists(atPath: url.path) ? url : nil
        })
      apply(); onPrepared?()
    }
  }
  func clear() {
    enabled = false; path = nil; artwork = nil; artworkPath = nil
    apply()
  }
  private func elapsed() -> Double {
    guard let info = snapshot else { return 0 }
    let start = (info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? NSNumber)?.doubleValue ?? 0
    let rate = (info[MPNowPlayingInfoPropertyPlaybackRate] as? NSNumber)?.doubleValue ?? 0
    let value = max(0, start + max(0, ProcessInfo.processInfo.systemUptime - snapshotAt) * rate)
    let duration = (info[MPMediaItemPropertyPlaybackDuration] as? NSNumber)?.doubleValue ?? 0
    return duration > 0 ? min(duration, value) : value
  }
  private func currentLine() -> String? {
    guard lyricsEnabled, lyricID == publishedID else { return nil }
    let position = elapsed()
    guard let index = lines.lastIndex(where: { $0.0 <= position }) else { return nil }
    // No timed ending exists in ordinary LRC; stop showing a stale last line.
    if index == lines.count - 1 && position > lines[index].0 + 12 { return nil }
    return lines[index].1
  }
  private func syncTimer() {
    let rate = (snapshot?[MPNowPlayingInfoPropertyPlaybackRate] as? NSNumber)?.doubleValue ?? 0
    let on = lyricsEnabled && lyricID == publishedID && !lines.isEmpty && rate > 0
    if !on { lyricTimer?.cancel(); lyricTimer = nil; return }
    guard lyricTimer == nil else { return }
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250), leeway: .milliseconds(50))
    timer.setEventHandler { [weak self] in
      guard let self = self else { return }
      let line = self.currentLine()
      if line != self.lastLine { self.apply() }
    }
    lyricTimer = timer; timer.resume()
  }
  private func apply() {
    guard var info = snapshot else { return }
    // Re-publishing metadata must advance the original clock, never rewind it.
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed()
    let line = currentLine(); lastLine = line
    if artistLyrics, let line = line { info[MPMediaItemPropertyArtist] = line }
    prepareLyricArtwork(line: line)
    if fullLyrics, lyricID == publishedID, line != nil, let poster = lyricStatic { info[MPMediaItemPropertyArtwork] = poster }
    if #available(iOS 26.0, *) {
      info.removeValue(forKey: MPNowPlayingInfoProperty1x1AnimatedArtwork)
      info.removeValue(forKey: MPNowPlayingInfoProperty3x4AnimatedArtwork)
      let key = portrait ? MPNowPlayingInfoProperty3x4AnimatedArtwork : MPNowPlayingInfoProperty1x1AnimatedArtwork
      retainedPath = nil
      if fullLyrics, lyricID == publishedID, line != nil, let clip = lyricMotion, let lyricKey = lyricArtworkKey,
        MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys.contains(lyricKey) {
        info[lyricKey] = clip; retainedPath = lyricPath
      } else if enabled, mediaID == publishedID, let artwork = artwork, MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys.contains(key) {
        info[key] = artwork; retainedPath = artworkPath
      }
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }
  private func prepareLyricArtwork(line: String?) {
    guard fullLyrics, lyricsEnabled, lyricID == publishedID, let id = lyricID, let line = line,
      let index = lines.lastIndex(where: { $0.0 <= elapsed() }) else {
      lyricTask?.cancel(); lyricTask = nil; lyricArtworkID = nil; lyricStatic = nil; lyricMotion = nil; lyricPath = nil
      return
    }
    let next = index + 1 < lines.count ? lines[index + 1].1 : nil
    let identity = SHA256.hash(data: Data("\(id):\(index):\(line)".utf8)).map { String(format: "%02x", $0) }.joined()
    if identity == lyricArtworkID { return }
    lyricArtworkID = identity; lyricTask?.cancel()
    var tall = true
    if #available(iOS 26.0, *) { tall = MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys.contains(MPNowPlayingInfoProperty3x4AnimatedArtwork) }
    let isTall = tall
    let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("musyn-lock-lyrics", isDirectory: true)
    let output = root.appendingPathComponent(identity + (isTall ? "-tall.mp4" : "-square.mp4"))
    lyricTask = Task.detached(priority: .userInitiated) { [weak self] in
      do {
        let image = try MusynLyricArtwork.poster(current: line, next: next, height: isTall ? 960 : 720)
        let url = try await MusynLyricArtwork.clip(image: image, at: output)
        try Task.checkCancellation()
        await MainActor.run { [weak self] in
          guard let self = self, self.lyricArtworkID == identity, self.lyricID == id, self.publishedID == id else { return }
          let preview = UIImage(cgImage: image)
          self.lyricStatic = MPMediaItemArtwork(boundsSize: preview.size) { _ in preview }
          self.lyricPath = url.path
          if #available(iOS 26.0, *) {
            self.lyricArtworkKey = isTall ? MPNowPlayingInfoProperty3x4AnimatedArtwork : MPNowPlayingInfoProperty1x1AnimatedArtwork
            self.lyricMotion = MPMediaItemAnimatedArtwork(artworkID: url.lastPathComponent,
              previewImageRequestHandler: { _ in preview }, videoAssetFileURLRequestHandler: { _ in
                FileManager.default.fileExists(atPath: url.path) ? url : nil
              })
          }
          self.apply()
          self.trimLyricFiles(root, keeping: url)
        }
      } catch { /* The normal cover remains when lyric artwork cannot be prepared. */ }
    }
  }
  private func trimLyricFiles(_ folder: URL, keeping current: URL) {
    // Called on the main queue: never remove a clip published by a newer seek.
    let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
      .filter { $0.pathExtension == "mp4" && !$0.lastPathComponent.contains("partial") }
      .sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
    for file in files.dropFirst(6) where file != current && file.path != retainedPath && file.path != lyricPath { try? FileManager.default.removeItem(at: file) }
  }

  func diagnostics() -> [String: Any] {
    let info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    var result: [String: Any] = ["duration": info[MPMediaItemPropertyPlaybackDuration] ?? 0,
      "elapsed": info[MPNowPlayingInfoPropertyElapsedPlaybackTime] ?? 0,
      "rate": info[MPNowPlayingInfoPropertyPlaybackRate] ?? 0,
      "live": info[MPNowPlayingInfoPropertyIsLiveStream] ?? false,
      "preparationFailed": failedPath != nil, "clipReady": artwork != nil, "published": retainedPath != nil,
      "sameItem": mediaID == publishedID, "lyrics": lyricsEnabled && !lines.isEmpty]
    if #available(iOS 26.0, *) { result["formats"] = MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys }
    return result
  }
}

/// Adapt a real clip to a platform-supported ratio; no synthesized cover motion.
private enum MusynArtworkVariant {
  @available(iOS 26.0, *)
  static func prepare(_ url: URL, keys: [String]) async throws -> URL {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw NSError(domain: "artwork", code: 1) }
    let size = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let bounds = CGRect(origin: .zero, size: size).applying(transform)
    let ratio = abs(bounds.width / bounds.height)
    let square = keys.contains(MPNowPlayingInfoProperty1x1AnimatedArtwork)
    let tall = keys.contains(MPNowPlayingInfoProperty3x4AnimatedArtwork)
    if (abs(ratio - 1) < 0.03 && square) || (abs(ratio - 0.75) < 0.03 && tall) { return url }
    guard square || tall else { throw NSError(domain: "artwork", code: 2) }
    let target = tall ? CGSize(width: 720, height: 960) : CGSize(width: 720, height: 720)
    let result = url.deletingPathExtension().appendingPathExtension(tall ? "portrait.mp4" : "square.mp4")
    if FileManager.default.fileExists(atPath: result.path) { return result }
    let output = result.deletingPathExtension().appendingPathExtension("partial")
    try? FileManager.default.removeItem(at: output)
    let composition = AVMutableVideoComposition()
    composition.renderSize = target; composition.frameDuration = CMTime(value: 1, timescale: 30)
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    let scale = max(target.width / abs(bounds.width), target.height / abs(bounds.height))
    let adjusted = transform.concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
      .concatenating(CGAffineTransform(scaleX: scale, y: scale))
      .concatenating(CGAffineTransform(translationX: (target.width - abs(bounds.width) * scale) / 2, y: (target.height - abs(bounds.height) * scale) / 2))
    layer.setTransform(adjusted, at: .zero); instruction.layerInstructions = [layer]; composition.instructions = [instruction]
    guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { throw NSError(domain: "artwork", code: 3) }
    exporter.videoComposition = composition
    do {
      try await exporter.export(to: output, as: .mp4)
      let attrs = try FileManager.default.attributesOfItem(atPath: output.path)
      guard (attrs[.size] as? NSNumber)?.intValue ?? Int.max <= 20 * 1024 * 1024 else { throw NSError(domain: "artwork", code: 4) }
      try FileManager.default.moveItem(at: output, to: result)
      return result
    } catch { try? FileManager.default.removeItem(at: output); throw error }
  }
}

private final class MusynPlayerMenuFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView { MusynPlayerMenu(frame: frame, id: id, messenger: messenger) }
}
private final class MusynPlayerMenu: NSObject, FlutterPlatformView {
  private let button = UIButton(type: .system)
  private let channel: FlutterMethodChannel
  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.vorynlabs.musyn/player_menu/\(id)", binaryMessenger: messenger)
    super.init()
    button.frame = frame
    button.setImage(UIImage(systemName: "ellipsis", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)), for: .normal)
    button.accessibilityLabel = "Track options"
    button.showsMenuAsPrimaryAction = true
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "configure", let args = call.arguments as? [String: Any], let id = args["id"] as? String else { result(FlutterMethodNotImplemented); return }
      self.button.overrideUserInterfaceStyle = args["dark"] as? Bool == true ? .dark : .light
      self.button.tintColor = .label
      let rows = args["items"] as? [[String: Any]] ?? []
      self.button.menu = UIMenu(children: rows.compactMap { row in
        guard let index = row["index"] as? Int, let title = row["title"] as? String else { return nil }
        return UIAction(title: title, image: UIImage(systemName: row["symbol"] as? String ?? "circle"), state: row["selected"] as? Bool == true ? .on : .off) { [weak self] _ in
          self?.channel.invokeMethod("action", arguments: ["id": id, "index": index])
        }
      })
      result(nil)
    }
  }
  func view() -> UIView { button }
  deinit { channel.setMethodCallHandler(nil) }
}
