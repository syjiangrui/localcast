import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var backendProcess: Process?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    startBackend()
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    stopBackend()
  }

  private func startBackend() {
    guard let binaryURL = locateBackendBinary() else {
      NSLog("LocalCast: backend binary not found")
      return
    }

    let process = Process()
    process.executableURL = binaryURL
    process.arguments = ["--api"]
    process.standardInput = FileHandle.nullDevice

    do {
      try process.run()
      backendProcess = process
      NSLog("LocalCast: backend started (pid %d) from %@", process.processIdentifier, binaryURL.path)
    } catch {
      NSLog("LocalCast: failed to start backend: %@", error.localizedDescription)
    }
  }

  /// Look for the backend binary: first inside the .app bundle (production),
  /// then in the Cargo build output (development via `flutter run`).
  private func locateBackendBinary() -> URL? {
    let bundleURL = Bundle.main.bundleURL

    // 1. Production: binary placed in Contents/Helpers/ by build_app.sh
    //    (Cannot use Contents/MacOS/ because macOS has a case-insensitive
    //    filesystem and the Flutter executable is also named LocalCast.)
    let helpersURL = bundleURL.appendingPathComponent("Contents/Helpers/localcast")
    if FileManager.default.isExecutableFile(atPath: helpersURL.path) {
      return helpersURL
    }

    // 2. Development: walk up from the bundle to find the project root's target/ dir.
    var dir = bundleURL
    for _ in 0..<10 {
      dir = dir.deletingLastPathComponent()
      let cargoToml = dir.appendingPathComponent("Cargo.toml")
      if FileManager.default.fileExists(atPath: cargoToml.path) {
        for profile in ["release", "debug"] {
          let candidate = dir.appendingPathComponent("target/\(profile)/localcast")
          if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
          }
        }
        break
      }
    }

    return nil
  }

  private func stopBackend() {
    guard let process = backendProcess, process.isRunning else { return }
    process.terminate()
    process.waitUntilExit()
    backendProcess = nil
  }
}
