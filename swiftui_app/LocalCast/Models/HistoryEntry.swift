import Foundation
import SwiftData

@Model
final class HistoryEntry {
    @Attribute(.unique) var filePath: String
    var fileName: String
    var lastProgressSecs: Int
    var lastPlayedAt: Date

    @Transient var fileExists: Bool = true

    init(filePath: String, fileName: String, lastProgressSecs: Int = 0, lastPlayedAt: Date = .now) {
        self.filePath = filePath
        self.fileName = fileName
        self.lastProgressSecs = lastProgressSecs
        self.lastPlayedAt = lastPlayedAt
    }
}
