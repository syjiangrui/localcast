import SwiftUI
import SwiftData

enum NavigationRoute: Hashable {
    case deviceList
    case playback
}

struct ContentView: View {
    @Environment(BackendManager.self) private var backendManager
    @Environment(\.modelContext) private var modelContext
    @State private var path = NavigationPath()
    @State private var fileVM: FileViewModel?
    @State private var deviceVM: DeviceViewModel?
    @State private var playbackVM: PlaybackViewModel?
    @State private var historyVM: HistoryViewModel?

    var body: some View {
        NavigationStack(path: $path) {
            if let fileVM, let historyVM {
                FilePickerView(path: $path, fileVM: fileVM, historyVM: historyVM)
                    .navigationDestination(for: NavigationRoute.self) { route in
                        switch route {
                        case .deviceList:
                            if let deviceVM, let playbackVM {
                                DeviceListView(path: $path, deviceVM: deviceVM, playbackVM: playbackVM)
                            }
                        case .playback:
                            if let playbackVM {
                                PlaybackView(path: $path, playbackVM: playbackVM)
                            }
                        }
                    }
            }
        }
        .onAppear {
            setupViewModels()
        }
    }

    private func setupViewModels() {
        guard fileVM == nil else { return }
        let api = ApiService(port: backendManager.backendPort)
        let sse = SseService(port: backendManager.backendPort)

        let fvm = FileViewModel(api: api)
        let dvm = DeviceViewModel(api: api, sse: sse)
        let hvm = HistoryViewModel()
        hvm.setModelContext(modelContext)
        let pvm = PlaybackViewModel(api: api, sse: sse)
        pvm.fileViewModel = fvm
        pvm.historyViewModel = hvm

        fileVM = fvm
        deviceVM = dvm
        historyVM = hvm
        playbackVM = pvm

        hvm.load()
    }
}
