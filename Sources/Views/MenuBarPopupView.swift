import SwiftUI
import AppKit

public struct MenuBarPopupView: View {
    @ObservedObject var monitor = ClipboardMonitorService.shared
    @ObservedObject var prefs = AppPreferences.shared
    @ObservedObject var syncService = NetworkSyncService.shared

    @State private var searchText: String = ""
    @State private var hoveredClipId: UUID?

    public var onClose: () -> Void
    public var onOpenPreferences: (PreferencesView.Tab) -> Void
    public var onQuit: () -> Void

    public init(
        onClose: @escaping () -> Void,
        onOpenPreferences: @escaping (PreferencesView.Tab) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onClose = onClose
        self.onOpenPreferences = onOpenPreferences
        self.onQuit = onQuit
    }

    var filteredClips: [ClipItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return monitor.clips
        }
        return monitor.clips.filter {
            $0.text.localizedCaseInsensitiveContains(searchText) ||
            ($0.appName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header: Brand & Search Bar
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 13, weight: .bold))
                            .rotationEffect(.degrees(-45))
                            .foregroundColor(.blue)
                        Text("BlueClip")
                            .font(.system(size: 13, weight: .bold))
                    }

                    Spacer()

                    Text("\(monitor.clips.count) clips")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    Button(action: {
                        syncService.performSync(clips: monitor.clips)
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(syncService.isServerReachable ? Color.green : Color.blue)
                                .frame(width: 7, height: 7)
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Sync clipboard with configured server")
                }

                // Search Input Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("Search clipboard history…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .padding(10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Scrollable List of Clips
            if filteredClips.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(searchText.isEmpty ? "No clippings yet" : "No matching clips found")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    if searchText.isEmpty {
                        Text("Copy text anywhere on your Mac to automatically start recording your history.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filteredClips.enumerated()), id: \.element.id) { index, clip in
                            ClipRowView(
                                clip: clip,
                                index: index < 9 ? index + 1 : nil,
                                maxSnippetLength: prefs.maxSnippetLength,
                                isHovered: hoveredClipId == clip.id,
                                onSelect: {
                                    monitor.selectClip(clip, autoPaste: prefs.autoPaste)
                                    onClose()
                                },
                                onTogglePin: {
                                    monitor.togglePin(id: clip.id)
                                },
                                onDelete: {
                                    monitor.deleteClip(id: clip.id)
                                }
                            )
                            .onHover { hovering in
                                hoveredClipId = hovering ? clip.id : nil
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .frame(height: 330)
            }

            Divider()

            // Footer Control Bar
            HStack(spacing: 12) {
                // Sync status indicator
                Button(action: {
                    onOpenPreferences(.sync)
                }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(syncService.isServerReachable ? Color.green : Color.blue)
                            .frame(width: 7, height: 7)
                        Text(syncService.isServerReachable ? "Cloud Sync" : "Private Sync")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Configure Private Cloud Sync")

                Spacer()

                Button(action: {
                    monitor.clearAll()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Unpinned History")

                Button(action: {
                    onOpenPreferences(.general)
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Preferences…")

                Button(action: onQuit) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit BlueClip")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 360)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
