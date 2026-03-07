import SwiftUI

struct DeviceListView: View {
    @Binding var path: NavigationPath
    @Bindable var deviceVM: DeviceViewModel
    @Bindable var playbackVM: PlaybackViewModel

    var body: some View {
        Group {
            if deviceVM.scanning {
                scanningView
            } else if let error = deviceVM.error {
                errorView(error)
            } else if deviceVM.devices.isEmpty {
                emptyView
            } else {
                deviceList
            }
        }
        .navigationTitle(String(localized: "selectDeviceTitle"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if deviceVM.scanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await deviceVM.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help(String(localized: "rescan"))
                }
            }
        }
        .task {
            await deviceVM.discover()
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text(String(localized: "scanningDevices"))
                .font(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(message)
            Button {
                Task { await deviceVM.refresh() }
            } label: {
                Label(String(localized: "retry"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty

    private var emptyView: some View {
        let hasDiscoveryError = deviceVM.discoveryError != nil

        return ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                Circle()
                    .fill(hasDiscoveryError ? Color.red.opacity(0.12) : Color.secondary.opacity(0.12))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: hasDiscoveryError ? "wifi.slash" : "tv.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(hasDiscoveryError ? .red : .secondary)
                    )

                Spacer().frame(height: 20)

                Text(hasDiscoveryError ? String(localized: "networkTroubleshootTitle") : String(localized: "noDevicesFound"))
                    .font(.headline)

                Spacer().frame(height: 8)

                Text(hasDiscoveryError ? String(localized: "networkTroubleshootHint") : String(localized: "noDevicesHint"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if hasDiscoveryError {
                    Spacer().frame(height: 16)
                    troubleshootingTips
                }

                Spacer().frame(height: 20)

                Button {
                    Task { await deviceVM.refresh() }
                } label: {
                    Label(String(localized: "scanAgain"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
        }
    }

    private var troubleshootingTips: some View {
        let tips: [String] = [
            String(localized: "networkTipCheckNetwork"),
            String(localized: "networkTipSameNetwork"),
            String(localized: "networkTipLocalNetwork"),
            String(localized: "networkTipFirewall"),
        ]

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 6) {
                    Text("\u{2022}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    // MARK: - Device List

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(deviceVM.devices.enumerated()), id: \.element.id) { index, device in
                    Button {
                        Task { await selectDevice(index) }
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "tv")
                                        .foregroundStyle(Color.accentColor)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.friendlyName)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(device.deviceUrl)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func selectDevice(_ index: Int) async {
        let selected = await deviceVM.selectDevice(index)
        guard selected else { return }
        let casted = await playbackVM.cast()
        if casted {
            path.append(NavigationRoute.playback)
        }
    }
}
