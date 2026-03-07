import Foundation
import SwiftData

@Observable
final class HistoryViewModel {
    var entries: [HistoryEntry] = []

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    @MainActor
    func load() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
        checkFilesExist()
    }

    @MainActor
    func recordFileSelected(filePath: String, fileName: String) {
        guard let modelContext else { return }

        // Try to find existing entry
        let predicate = #Predicate<HistoryEntry> { $0.filePath == filePath }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.fileName = fileName
            existing.lastPlayedAt = .now
        } else {
            let entry = HistoryEntry(filePath: filePath, fileName: fileName)
            modelContext.insert(entry)
        }

        try? modelContext.save()
        trimEntries()
        load()
    }

    @MainActor
    func updateProgress(filePath: String, secs: Int) {
        guard let modelContext else { return }

        let predicate = #Predicate<HistoryEntry> { $0.filePath == filePath }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        if let entry = try? modelContext.fetch(descriptor).first {
            entry.lastProgressSecs = secs
            entry.lastPlayedAt = .now
            try? modelContext.save()
        }
        load()
    }

    @MainActor
    func deleteEntry(_ entry: HistoryEntry) {
        guard let modelContext else { return }
        modelContext.delete(entry)
        try? modelContext.save()
        load()
    }

    private func trimEntries() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        guard let all = try? modelContext.fetch(descriptor), all.count > 50 else { return }
        for entry in all.dropFirst(50) {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private func checkFilesExist() {
        for entry in entries {
            entry.fileExists = FileManager.default.fileExists(atPath: entry.filePath)
        }
    }
}
