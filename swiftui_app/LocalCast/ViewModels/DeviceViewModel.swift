import Foundation

@Observable
final class DeviceViewModel {
    var devices: [DlnaDevice] = []
    var selectedIndex: Int?
    var scanning = false
    var error: String?
    var discoveryError: String?

    var selectedDevice: DlnaDevice? {
        guard let idx = selectedIndex, idx < devices.count else { return nil }
        return devices[idx]
    }

    private let api: ApiService
    private let sse: SseService
    private var sseTask: Task<Void, Never>?

    init(api: ApiService, sse: SseService) {
        self.api = api
        self.sse = sse
    }

    @MainActor
    func discover() async {
        scanning = true
        error = nil

        do {
            let result = try await api.discover()
            devices = result.devices
            discoveryError = result.discoveryError
            selectedIndex = nil
            scanning = false
            subscribeSse()
        } catch {
            self.error = error.localizedDescription
            scanning = false
        }
    }

    @MainActor
    func refresh() async {
        scanning = true
        error = nil

        do {
            let result = try await api.discoverRefresh()
            devices = result.devices
            discoveryError = result.discoveryError
            selectedIndex = nil
            scanning = false
            subscribeSse()
        } catch {
            self.error = error.localizedDescription
            scanning = false
        }
    }

    @MainActor
    func selectDevice(_ index: Int) async -> Bool {
        error = nil

        do {
            try await api.selectDevice(index)
            selectedIndex = index
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    @MainActor
    func reset() {
        unsubscribeSse()
        devices = []
        selectedIndex = nil
        error = nil
        discoveryError = nil
    }

    private func subscribeSse() {
        unsubscribeSse()
        sseTask = Task { [weak self] in
            guard let self else { return }
            for await result in self.sse.devicesStream() {
                if Task.isCancelled { break }
                await MainActor.run {
                    self.devices = result.devices
                    self.discoveryError = result.discoveryError
                    if let idx = self.selectedIndex, idx >= self.devices.count {
                        self.selectedIndex = nil
                    }
                }
            }
        }
    }

    private func unsubscribeSse() {
        sseTask?.cancel()
        sseTask = nil
    }

    deinit {
        sseTask?.cancel()
    }
}
