import Flutter
import UIKit
import MediaPlayer
import AVKit
import AVFoundation
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var favoritesChannel: FlutterMethodChannel?
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
