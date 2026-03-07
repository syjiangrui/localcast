import Foundation
import os

enum BackendState: Equatable {
    case starting
    case ready
    case failed(String)
}

@Observable
final class BackendManager {
    static weak var shared: BackendManager?

    var state: BackendState = .starting
    var backendPort: UInt16 = 0

    private var backendProcess: Process?
    private let logger = Logger(subsystem: "com.reikly.localcast", category: "BackendManager")

    init() {
        BackendManager.shared = self
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        startBackend()
        if backendPort > 0 {
            let ok = await waitForBackend()
            await MainActor.run {
                if ok {
                    state = .ready
                } else {
                    state = .failed("Backend did not respond within 10 seconds")
                }
            }
        } else {
            await MainActor.run {
                state = .failed("Failed to start backend process")
            }
        }
    }

    private func startBackend() {
        guard let binaryURL = locateBackendBinary() else {
            logger.error("Backend binary not found")
            return
        }

        // Kill any previously orphaned backend process.
        let killer = Process()
        killer.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killer.arguments = ["-f", "localcast --api"]
        try? killer.run()
        killer.waitUntilExit()

        let pipe = Pipe()
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = ["--api", "--api-port", "0"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe

        do {
            try process.run()
            backendProcess = process
        } catch {
            logger.error("Failed to start backend: \(error.localizedDescription)")
            return
        }

        // Read stdout synchronously to parse the actual port.
        let fileHandle = pipe.fileHandleForReading
        let data = fileHandle.availableData
        if let line = String(data: data, encoding: .utf8),
           let match = line.range(of: "LOCALCAST_PORT=") {
            let portStr = line[match.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if let port = UInt16(portStr) {
                backendPort = port
                logger.info("Backend reported port \(port)")
            }
        }

        logger.info("Backend started (pid \(process.processIdentifier)) on port \(self.backendPort) from \(binaryURL.path)")
    }

    private func locateBackendBinary() -> URL? {
        let bundleURL = Bundle.main.bundleURL

        // 1. Production: binary placed in Contents/Helpers/ by build_app.sh
        let helpersURL = bundleURL.appendingPathComponent("Contents/Helpers/localcast")
        if FileManager.default.isExecutableFile(atPath: helpersURL.path) {
            return helpersURL
        }

        // 2. Development: walk up from the bundle to find the project root's target/ dir.
        //    This works when the build output is inside the project tree.
        var dir = bundleURL
        for _ in 0..<10 {
            dir = dir.deletingLastPathComponent()
            if let found = findBackendInProjectRoot(dir) { return found }
        }

        // 3. Development (Xcode): DerivedData is outside the project tree.
        //    Walk up from the .xcodeproj (swiftui_app/) to the repo root.
        let sourceDir = URL(fileURLWithPath: #filePath)   // …/LocalCast/App/BackendManager.swift
            .deletingLastPathComponent()                   // …/LocalCast/App/
            .deletingLastPathComponent()                   // …/LocalCast/
            .deletingLastPathComponent()                   // …/swiftui_app/
        var ancestor = sourceDir
        for _ in 0..<5 {
            if let found = findBackendInProjectRoot(ancestor) { return found }
            ancestor = ancestor.deletingLastPathComponent()
        }

        return nil
    }

    /// Check if `dir` contains Cargo.toml and return the backend binary if found.
    private func findBackendInProjectRoot(_ dir: URL) -> URL? {
        let cargoToml = dir.appendingPathComponent("Cargo.toml")
        guard FileManager.default.fileExists(atPath: cargoToml.path) else { return nil }
        for profile in ["release", "debug"] {
            let candidate = dir.appendingPathComponent("target/\(profile)/localcast")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private func waitForBackend() async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            do {
                let url = URL(string: "http://127.0.0.1:\(backendPort)/api/status")!
                let (_, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    return true
                }
            } catch {
                // Backend not ready yet
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return false
    }

    func stopBackend() {
        guard let process = backendProcess, process.isRunning else { return }
        process.terminate()
        process.waitUntilExit()
        backendProcess = nil
        logger.info("Backend stopped")
    }

    deinit {
        stopBackend()
    }
}
