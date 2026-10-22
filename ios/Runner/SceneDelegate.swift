import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene,
      let app = UIApplication.shared.delegate as? AppDelegate else { return }
    let window = UIWindow(windowScene: windowScene)
    let controller = FlutterViewController(engine: app.musynEngine, nibName: nil, bundle: nil)
    controller.loadDefaultSplashScreenView()
    window.rootViewController = controller
    self.window = window
    // Forward scene lifecycle and incoming links through Flutter's delegate.
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    window.makeKeyAndVisible()
  }
}
