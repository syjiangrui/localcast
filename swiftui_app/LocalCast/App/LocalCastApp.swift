import SwiftUI
import SwiftData

@main
struct LocalCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var backendManager = BackendManager()

    var body: some Scene {
        WindowGroup {
            Group {
                switch backendManager.state {
                case .starting:
                    SplashView()
                case .ready:
                    ContentView()
                case .failed(let message):
                    ErrorView(message: message)
                }
            }
            .environment(backendManager)
        }
        .defaultSize(width: 800, height: 560)
        .modelContainer(for: HistoryEntry.self)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        BackendManager.shared?.stopBackend()
    }
}

private struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Failed to start backend")
                .font(.headline)
            Text("后台服务未能在规定时间内响应。")
                .foregroundStyle(.secondary)
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
