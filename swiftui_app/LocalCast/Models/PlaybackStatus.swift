import Foundation

struct PlaybackStatus: Codable {
    let playbackState: String
    let elapsedSecs: Int
    let durationSecs: Int
    let elapsedDisplay: String
    let durationDisplay: String
    let progress: Double
    let fileName: String
    let deviceName: String

    static func empty() -> PlaybackStatus {
        PlaybackStatus(
            playbackState: "Stopped",
            elapsedSecs: 0,
            durationSecs: 0,
            elapsedDisplay: "00:00:00",
            durationDisplay: "00:00:00",
            progress: 0,
            fileName: "",
            deviceName: ""
        )
    }
}

struct FileInfo: Codable {
    let fileName: String
    let fileSize: Int
    let mimeType: String
}

struct DiscoverResult: Codable {
    let devices: [DlnaDevice]
    let discoveryError: String?
}
