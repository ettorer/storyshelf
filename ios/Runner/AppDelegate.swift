import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StoryShelfOpenFile")
    let channel = FlutterMethodChannel(
      name: "storyshelf/open_file",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "takePendingFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let defaults = UserDefaults.standard
      let path = defaults.string(forKey: "storyshelf.pendingAudioFile")
      defaults.removeObject(forKey: "storyshelf.pendingAudioFile")
      if path == nil,
         let error = defaults.string(forKey: "storyshelf.pendingAudioError") {
        defaults.removeObject(forKey: "storyshelf.pendingAudioError")
        result(FlutterError(code: "FILE_OPEN_FAILED", message: error, details: nil))
        return
      }
      result(path)
    }
  }
}
