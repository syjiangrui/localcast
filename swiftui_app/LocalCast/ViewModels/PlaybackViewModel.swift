import Foundation

@Observable
final class PlaybackViewModel {
    var status: PlaybackStatus = .empty()
    var casting = false
    var error: String?

    var isPlaying: Bool { status.playbackState == "Playing" }
    var isPaused: Bool { status.playbackState == "Paused" }
    var isStopped: Bool { status.playbackState == "Stopped" }

    private let api: ApiService
    private let sse: SseService
    private var sseTask: Task<Void, Never>?

    // References for saving progress on stop
    var fileViewModel: FileViewModel?
    var historyViewModel: HistoryViewModel?

    init(api: ApiService, sse: SseService) {
        self.api = api
        self.sse = sse
    }

    @MainActor
    func cast() async -> Bool {
        casting = true
        error = nil

        do {
            try await api.cast()
            casting = false
            subscribeSse()
            return true
        } catch {
            self.error = error.localizedDescription
            casting = false
            return false
        }
    }

    @MainActor
    func play() async {
        do {
            try await api.play()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func pause() async {
        do {
            try await api.pause()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func togglePlayPause() async {
        if isPlaying {
            await pause()
        } else if isStopped {
            _ = await cast()
        } else {
            await play()
        }
    }

    @MainActor
    func stop() async {
        do {
            // Save progress before stopping
            if let path = fileViewModel?.filePath, status.elapsedSecs > 0 {
                historyViewModel?.updateProgress(filePath: path, secs: status.elapsedSecs)
            }
            try await api.stop()
            unsubscribeSse()
            status = .empty()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func seek(_ positionSecs: Int) async {
        do {
            try await api.seek(positionSecs)
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func seekRelative(_ deltaSecs: Int) async {
        var target = status.elapsedSecs + deltaSecs
        if target < 0 { target = 0 }
        if status.durationSecs > 0 && target > status.durationSecs {
            target = status.durationSecs
        }
        await seek(target)
    }

    @MainActor
    func reset() {
        unsubscribeSse()
        status = .empty()
        error = nil
    }

    private func subscribeSse() {
        unsubscribeSse()
        sseTask = Task { [weak self] in
            guard let self else { return }
            for await newStatus in self.sse.statusStream() {
                if Task.isCancelled { break }
                await MainActor.run {
                    self.status = newStatus
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
