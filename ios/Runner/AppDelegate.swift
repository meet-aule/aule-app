import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// A plain paper-coloured view over each window while the app is in the
  /// background, so the app switcher's snapshot shows nothing about a child.
  /// System alerts do not trigger it: they only make the app inactive.
  private var covers: [ObjectIdentifier: UIView] = [:]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(coverScene(_:)),
      name: UIScene.didEnterBackgroundNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(uncoverScene(_:)),
      name: UIScene.willEnterForegroundNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  @objc private func coverScene(_ notification: Notification) {
    guard let scene = notification.object as? UIWindowScene else { return }
    for window in scene.windows where covers[ObjectIdentifier(window)] == nil {
      let cover = UIView(frame: window.bounds)
      cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      cover.backgroundColor = UIColor(
        red: 245.0 / 255.0,
        green: 242.0 / 255.0,
        blue: 234.0 / 255.0,
        alpha: 1.0
      )
      window.addSubview(cover)
      covers[ObjectIdentifier(window)] = cover
    }
  }

  @objc private func uncoverScene(_ notification: Notification) {
    guard let scene = notification.object as? UIWindowScene else { return }
    for window in scene.windows {
      covers.removeValue(forKey: ObjectIdentifier(window))?.removeFromSuperview()
    }
  }
}
