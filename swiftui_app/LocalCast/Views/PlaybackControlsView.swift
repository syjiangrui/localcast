import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var playbackVM: PlaybackViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Main controls row
            HStack(spacing: 8) {
                // -5 min
                Button {
                    Task { await playbackVM.seekRelative(-300) }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(playbackVM.isStopped)
                .help(String(localized: "seekBackward5Min"))

                Spacer().frame(width: 4)

                // -30s
                Button {
                    Task { await playbackVM.seekRelative(-30) }
                } label: {
                    Image(systemName: "gobackward.30")
                        .font(.title)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(playbackVM.isStopped)
                .help(String(localized: "seekBackward30s"))

                Spacer().frame(width: 12)

                // Play/Pause/Replay
                Button {
                    Task { await playbackVM.togglePlayPause() }
                } label: {
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 32))
                        .frame(width: 64, height: 64)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())

                Spacer().frame(width: 12)

                // +30s
                Button {
                    Task { await playbackVM.seekRelative(30) }
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(playbackVM.isStopped)
                .help(String(localized: "seekForward30s"))

                Spacer().frame(width: 4)

                // +5 min
                Button {
                    Task { await playbackVM.seekRelative(300) }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(playbackVM.isStopped)
                .help(String(localized: "seekForward5Min"))
            }

            // Stop button
            Button {
                Task { await playbackVM.stop() }
            } label: {
                Label(String(localized: "stop"), systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .opacity(playbackVM.isStopped ? 0 : 1)
            .disabled(playbackVM.isStopped)
            .animation(.easeOut(duration: 0.2), value: playbackVM.isStopped)
        }
    }

    private var playPauseIcon: String {
        if playbackVM.isStopped { return "arrow.counterclockwise" }
        if playbackVM.isPlaying { return "pause.fill" }
        return "play.fill"
    }
}
