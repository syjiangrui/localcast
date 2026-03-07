import Foundation
import AppKit

@Observable
final class FileViewModel {
    var filePath: String?
    var fileName: String?
    var fileSize: Int?
    var mimeType: String?
    var loading = false
    var error: String?

    var hasFile: Bool { filePath != nil }

    private let api: ApiService

    init(api: ApiService) {
        self.api = api
    }

    @MainActor
    func pickFile() async -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "mp4")!,
            .init(filenameExtension: "mkv")!,
            .init(filenameExtension: "avi")!,
            .init(filenameExtension: "webm")!,
            .init(filenameExtension: "mov")!,
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return false }

        return await selectFile(path: url.path(percentEncoded: false))
    }

    @MainActor
    func selectFile(path: String) async -> Bool {
        loading = true
        error = nil

        do {
            let info = try await api.selectFile(path)
            filePath = path
            fileName = info.fileName
            fileSize = info.fileSize
            mimeType = info.mimeType
            loading = false
            return true
        } catch {
            self.error = error.localizedDescription
            loading = false
            return false
        }
    }

    @MainActor
    func reset() {
        filePath = nil
        fileName = nil
        fileSize = nil
        mimeType = nil
        error = nil
    }
}
