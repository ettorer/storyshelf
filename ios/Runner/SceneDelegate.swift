import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let url = connectionOptions.urlContexts.first?.url {
      saveIncomingAudio(url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
      saveIncomingAudio(url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  private func saveIncomingAudio(_ url: URL) {
    guard url.pathExtension.lowercased() == "mp3" else { return }
    let hasScopedAccess = url.startAccessingSecurityScopedResource()
    defer {
      if hasScopedAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent("incoming-\(UUID().uuidString).mp3")
    do {
      try FileManager.default.copyItem(at: url, to: destination)
      UserDefaults.standard.set(
        destination.path,
        forKey: "storyshelf.pendingAudioFile"
      )
    } catch {
      UserDefaults.standard.set(
        error.localizedDescription,
        forKey: "storyshelf.pendingAudioError"
      )
    }
  }
}
