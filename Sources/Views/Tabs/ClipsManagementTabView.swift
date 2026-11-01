import SwiftUI
import AppKit

public struct ClipsManagementTabView: View {
    @ObservedObject var monitor = ClipboardMonitorService.shared
    @State private var searchText = ""
    @State private var selectedClipId: UUID?
    @State private var showingClearAlert = false
    @State private var statusMessage: String?
    @State private var isImporting = false

    public init() {}

    var filteredClips: [ClipItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return monitor.clips
        }
        return monitor.clips.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Title and Search
            HStack(spacing: 12) {
                Text("Browse Clips")
                    .font(.system(size: 14, weight: .semibold))

                Text("(\(monitor.clips.count))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Search clips…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(5)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 220)
            }

            // Simple Clips List
            List(selection: $selectedClipId) {
                ForEach(filteredClips) { clip in
                    HStack(spacing: 10) {
                        if clip.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Text(clip.preview(limit: 75))
                            .font(.system(size: 12))
                            .lineLimit(1)

                        Spacer()

                        Text(clip.timeAgo)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 3)
                    .tag(clip.id)
                    .contextMenu {
                        Button("Copy to Clipboard") {
                            monitor.selectClip(clip, autoPaste: false)
                        }
                        Button(clip.isPinned ? "Unpin" : "Pin") {
                            monitor.togglePin(id: clip.id)
                        }
                        Divider()
                        Button("Delete") {
                            monitor.deleteClip(id: clip.id)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(height: 270)
            .border(Color.gray.opacity(0.2), width: 1)

            // Bottom Action Bar: Import / Export / Clear
            HStack(spacing: 12) {
                Button(action: runImportFromCopyClip) {
                    if isImporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Import from CopyClip")
                    }
                }
                .disabled(isImporting)

                Menu("Export…") {
                    Button("Export as JSON…") { exportFile(type: .json) }
                    Button("Export as Text…") { exportFile(type: .text) }
                    Button("Export as CSV…") { exportFile(type: .csv) }
                }

                if let msg = statusMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Clear History") {
                    showingClearAlert = true
                }
                .disabled(monitor.clips.isEmpty)
            }
        }
        .padding(18)
        .confirmationDialog("Clear Clipboard History?", isPresented: $showingClearAlert) {
            Button("Clear All", role: .destructive) {
                monitor.clearAll()
                statusMessage = "History cleared."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete unpinned clippings?")
        }
    }

    private func runImportFromCopyClip() {
        isImporting = true
        statusMessage = "Importing from CopyClip database…"

        CopyClipImporterService.shared.importDirectlyOrPrompt { result in
            DispatchQueue.main.async {
                self.isImporting = false
                switch result {
                case .success(let count):
                    self.statusMessage = "Imported \(count) clips from CopyClip."
                case .failure(let error):
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    enum ExportType { case json, text, csv }

    private func exportFile(type: ExportType) {
        let savePanel = NSSavePanel()
        switch type {
        case .json:
            savePanel.nameFieldStringValue = "BlueClip_History_\(Date().timeIntervalSince1970).json"
        case .text:
            savePanel.nameFieldStringValue = "BlueClip_History_\(Date().timeIntervalSince1970).txt"
        case .csv:
            savePanel.nameFieldStringValue = "BlueClip_History_\(Date().timeIntervalSince1970).csv"
        }

        if savePanel.runModal() == .OK, let url = savePanel.url {
            let content: String
            switch type {
            case .json:
                content = StorageService.shared.exportClipsAsJSON(clips: monitor.clips) ?? ""
            case .text:
                content = StorageService.shared.exportClipsAsText(clips: monitor.clips)
            case .csv:
                content = StorageService.shared.exportClipsAsCSV(clips: monitor.clips)
            }
            try? content.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Exported to \(url.lastPathComponent)."
        }
    }
}
