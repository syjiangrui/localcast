import SwiftUI

private let supportedExtensions = Set(["mp4", "mkv", "avi", "webm", "mov"])

struct FilePickerView: View {
    @Binding var path: NavigationPath
    @Bindable var fileVM: FileViewModel
    @Bindable var historyVM: HistoryViewModel
    @State private var isDragOver = false
    @State private var showHistory = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Main content
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Scrim overlay
            if showHistory {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showHistory = false } }
                    .transition(.opacity)
            }

            // History panel
            if showHistory {
                HistorySidePanel(historyVM: historyVM) { entry in
                    withAnimation(.easeOut(duration: 0.2)) { showHistory = false }
                    Task { await selectFromHistory(entry) }
                }
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showHistory)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showHistory.toggle() }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .help(String(localized: "historyToggle"))
                .background(showHistory ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .navigationTitle(String(localized: "appTitle"))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 24) {
            Spacer()

            dropZone
                .padding(.horizontal, 48)

            Spacer()
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            return handleDrop(url)
        } isTargeted: { targeted in
            isDragOver = targeted
        }
    }

    private var dropZone: some View {
        VStack(spacing: 0) {
            // Icon
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: isDragOver ? "arrow.down.doc" : "film")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)
                )

            Spacer().frame(height: 24)

            // Title
            Text(isDragOver ? String(localized: "dropVideoHere") : String(localized: "selectVideoTitle"))
                .font(.title2.weight(.semibold))

            Spacer().frame(height: 8)

            // Supported formats
            Text(String(localized: "supportedFormats"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 32)

            // File card or pick button
            if fileVM.hasFile {
                fileCard
                Spacer().frame(height: 16)
                Button {
                    path.append(NavigationRoute.deviceList)
                } label: {
                    Label(String(localized: "chooseDevice"), systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text(String(localized: "dragAndDropHint"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer().frame(height: 12)

                Button {
                    Task { await pickFile() }
                } label: {
                    if fileVM.loading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(String(localized: "selectVideoFile"), systemImage: "folder")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(fileVM.loading)
            }

            // Error
            if let error = fileVM.error {
                Spacer().frame(height: 16)
                Text(error)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        }
        .padding(40)
        .background(
            isDragOver ? Color.accentColor.opacity(0.05) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .dashedBorder(
            color: isDragOver ? .accentColor : .secondary.opacity(0.3),
            lineWidth: isDragOver ? 2.5 : 1.5
        )
    }

    private var fileCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "film")
                        .foregroundStyle(Color.accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(fileVM.fileName ?? "")
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(formatSize(fileVM.fileSize ?? 0))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                fileVM.reset()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
        .frame(maxWidth: 420)
    }

    // MARK: - Actions

    private func pickFile() async {
        let success = await fileVM.pickFile()
        if success, let p = fileVM.filePath, let name = fileVM.fileName {
            historyVM.recordFileSelected(filePath: p, fileName: name)
            path.append(NavigationRoute.deviceList)
        }
    }

    private func handleDrop(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { return false }

        Task {
            let success = await fileVM.selectFile(path: url.path(percentEncoded: false))
            if success {
                let name = fileVM.fileName ?? url.lastPathComponent
                historyVM.recordFileSelected(filePath: url.path(percentEncoded: false), fileName: name)
                path.append(NavigationRoute.deviceList)
            }
        }
        return true
    }

    private func selectFromHistory(_ entry: HistoryEntry) async {
        let success = await fileVM.selectFile(path: entry.filePath)
        if success {
            historyVM.recordFileSelected(filePath: entry.filePath, fileName: entry.fileName)
            path.append(NavigationRoute.deviceList)
        }
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
}
