import Flutter
import UIKit
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
      self?.favoriteTrackID = state["trackId"] as? String
      favorite.isActive = state["liked"] as? Bool ?? false
      favorite.isEnabled = self?.favoriteTrackID != nil
      result(nil)
    }
  }
}
