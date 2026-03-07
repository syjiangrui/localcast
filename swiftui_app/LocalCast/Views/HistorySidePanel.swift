import SwiftUI

struct HistorySidePanel: View {
    @Bindable var historyVM: HistoryViewModel
    let onSelect: (HistoryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "historyTitle"))
                    .font(.headline)
                if !historyVM.entries.isEmpty {
                    Text("(\(historyVM.entries.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            if historyVM.entries.isEmpty {
                Spacer()
                Text(String(localized: "historyEmpty"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(historyVM.entries) { entry in
                            HistoryTile(
                                entry: entry,
                                onTap: { if entry.fileExists { onSelect(entry) } },
                                onDelete: { historyVM.deleteEntry(entry) }
                            )
                        }
                    }
                }
            }
        }
        .frame(width: 280)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 2, y: 0)
    }
}

private struct HistoryTile: View {
    let entry: HistoryEntry
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(entry.fileExists ? Color.secondary.opacity(0.12) : Color.red.opacity(0.12))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: entry.fileExists ? "film" : "photo.badge.exclamationmark")
                            .font(.system(size: 14))
                            .foregroundStyle(entry.fileExists ? Color.secondary : Color.red)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.fileName)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundStyle(entry.fileExists ? .primary : .secondary)

                    Text(subtitle)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(entry.fileExists ? Color.secondary : Color.red)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!entry.fileExists)
    }

    private var subtitle: String {
        if !entry.fileExists {
            return String(localized: "historyFileMissing")
        }
        if entry.lastProgressSecs > 0 {
            return formatProgress(entry.lastProgressSecs)
        }
        return entry.filePath
    }

    private func formatProgress(_ secs: Int) -> String {
        if secs >= 3600 {
            let h = secs / 3600
            let m = (secs % 3600) / 60
            return "\(h)h \(String(format: "%02d", m))m"
        }
        let m = secs / 60
        let s = secs % 60
        return "\(String(format: "%02d", m)):\(String(format: "%02d", s))"
    }
}
