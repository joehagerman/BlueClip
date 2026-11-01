import SwiftUI
import AppKit

public struct AboutTabView: View {
    @ObservedObject var monitor = ClipboardMonitorService.shared
    @ObservedObject var prefs = AppPreferences.shared
    @ObservedObject var syncService = NetworkSyncService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 10)

            HStack(spacing: 24) {
                // Signature Blue Squircle Icon
                BlueClipLogoView(size: 110)

                VStack(alignment: .leading, spacing: 6) {
                    Text("BlueClip")
                        .font(.system(size: 26, weight: .bold))

                    Text("Version 2.0.0 (Native Apple Silicon)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("© 2026 BlueClip Contributors • MIT License")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("Next-generation menu bar clipboard manager with private cloud synchronization to AWS EC2 infrastructure.")
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)

                    Text("Tip: ⌘-Click the icon to cycle Easter Egg emojis (\(prefs.currentEmoji))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.top, 1)
                }
            }
            .padding(.horizontal, 20)

            // Diagnostics pill card
            VStack(spacing: 8) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACTIVE HISTORY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("\(monitor.clips.count) clips")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    }

                    Divider()
                        .frame(height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("NETWORK HUB")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(syncService.isServerReachable ? "Connected" : "Local Hub")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                    }

                    Divider()
                        .frame(height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SYNC STATUS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(syncService.isServerReachable ? Color.green : Color.blue)
                                .frame(width: 7, height: 7)
                            Text(syncService.isServerReachable ? "Online" : "Active")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(8)

            Spacer()

            // Bottom Action Links (matching the layout in the CopyClip screenshot)
            HStack(spacing: 12) {
                Button("Web History") {
                    AppDelegate.sharedInstance?.openLocalWebViewerSelected()
                }
                .buttonStyle(.bordered)

                Button("Cloud Viewer") {
                    AppDelegate.sharedInstance?.openWebViewerSelected()
                }
                .buttonStyle(.bordered)

                Button("Open Clips Folder") {
                    let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                    if let base = urls.first?.appendingPathComponent("BlueClip") {
                        NSWorkspace.shared.open(base)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 12)
        }
        .padding(20)
    }
}
