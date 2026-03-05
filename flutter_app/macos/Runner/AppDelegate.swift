import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var backendProcess: Process?
  var backendPort: UInt16 = 8080

  override func applicationWillFinishLaunching(_ notification: Notification) {
    startBackend()
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

    // Kill any previously orphaned backend process bound to port 8080.
    let killer = Process()
    killer.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
    killer.arguments = ["-f", "localcast --api"]
    try? killer.run()
    killer.waitUntilExit()

    backendPort = findAvailablePort()

    let process = Process()
    process.executableURL = binaryURL
    process.arguments = ["--api", "--api-port", "\(backendPort)"]
    process.standardInput = FileHandle.nullDevice

    do {
      try process.run()
      backendProcess = process
      NSLog("LocalCast: backend started (pid %d) on port %d from %@", process.processIdentifier, backendPort, binaryURL.path)
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

  /// Find a free TCP port by binding to port 0 and reading the assigned port.
  private func findAvailablePort() -> UInt16 {
    let sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard sock >= 0 else { return 8080 }
    defer { close(sock) }

    var addr = sockaddr_in()
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = 0  // Let the OS pick a free port
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")

    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bindResult == 0 else { return 8080 }

    var boundAddr = sockaddr_in()
    var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &boundAddr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        getsockname(sock, $0, &addrLen)
      }
    }
    guard nameResult == 0 else { return 8080 }

    let port = UInt16(bigEndian: boundAddr.sin_port)
    NSLog("LocalCast: found available port %d", port)
    return port
  }

  private func stopBackend() {
    guard let process = backendProcess, process.isRunning else { return }
    process.terminate()
    process.waitUntilExit()
    backendProcess = nil
  }
}
