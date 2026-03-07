import SwiftUI

struct PlaybackView: View {
    @Binding var path: NavigationPath
    @Bindable var playbackVM: PlaybackViewModel

    var body: some View {
        let status = playbackVM.status

        VStack(spacing: 0) {
            Spacer()

            // Cast icon
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "airplayvideo")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)
                )

            Spacer().frame(height: 16)

            // File name
            Text(status.fileName.isEmpty ? String(localized: "noFile") : status.fileName)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Spacer().frame(height: 8)

            // Device subtitle
            Text(status.deviceName.isEmpty ? String(localized: "noDevice") : String(localized: "castingTo \(status.deviceName)"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 8)

            // State chip
            stateChip(status.playbackState)

            Spacer()

            // Slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { status.durationSecs > 0 ? min(max(status.progress, 0), 1) : 0 },
                        set: { newValue in
                            let target = Int(newValue * Double(status.durationSecs))
                            Task { await playbackVM.seek(target) }
                        }
                    ),
                    in: 0...1
                )
                .disabled(status.durationSecs <= 0)

                HStack {
                    Text(status.elapsedDisplay)
                        .monospacedDigit()
                        .font(.caption)
                    Spacer()
                    Text(status.durationDisplay)
                        .monospacedDigit()
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            // Controls
            PlaybackControlsView(playbackVM: playbackVM)

            Spacer()
            Spacer()

            // Error
            if let error = playbackVM.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(24)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .navigationTitle(String(localized: "nowPlaying"))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    Task {
                        await playbackVM.stop()
                        path.removeLast()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .navigationBarBackButtonHidden()
    }

    @ViewBuilder
    private func stateChip(_ state: String) -> some View {
        let (color, icon) = stateStyle(state)

        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(localizedStateName(state))
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.3)))
    }

    private func stateStyle(_ state: String) -> (Color, String) {
        switch state {
        case "Playing": return (.green, "play.fill")
        case "Paused": return (.orange, "pause.fill")
        case "Stopped": return (.red, "stop.fill")
        case "Loading...": return (.blue, "hourglass")
        default: return (.secondary, "info.circle")
        }
    }

    private func localizedStateName(_ state: String) -> String {
        switch state {
        case "Playing": return String(localized: "playbackState.Playing")
        case "Paused": return String(localized: "playbackState.Paused")
        case "Stopped": return String(localized: "playbackState.Stopped")
        case "Loading...": return String(localized: "playbackState.Loading...")
        case "No Media": return String(localized: "playbackState.No Media")
        default: return state
        }
    }
}
