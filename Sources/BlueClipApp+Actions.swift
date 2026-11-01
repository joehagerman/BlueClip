import AppKit
import SwiftUI

extension AppDelegate {
    // MARK: - Actions

    @objc func toggleSortModeSelected() {
        let prefs = AppPreferences.shared
        prefs.sortMode = (prefs.sortMode == .chrono) ? .keyword : .chrono
    }

    @objc func setChronoSortSelected() {
        AppPreferences.shared.sortMode = .chrono
    }

    @objc func setKeywordSortSelected() {
        AppPreferences.shared.sortMode = .keyword
    }

    @objc func setChronoLimitFromMenuItem(_ sender: NSMenuItem) {
        AppPreferences.shared.chronoDisplayLimit = sender.tag
    }

    @objc func setTagSortModeFromMenuItem(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? AppPreferences.TagSortMode else { return }
        AppPreferences.shared.tagSortMode = mode
    }

    @objc func setTagLimitFromMenuItem(_ sender: NSMenuItem) {
        AppPreferences.shared.tagDisplayLimit = sender.tag
    }

    @objc func clipItemSelected(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? ClipItem else { return }
        ClipboardMonitorService.shared.selectClip(clip, autoPaste: AppPreferences.shared.autoPaste)
    }

    @objc func copyAllHistorySelected() {
        let clips = ClipboardMonitorService.shared.clips
        guard !clips.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Copy All Clips?"
        alert.informativeText = "Are you sure you want to combine all \(clips.count) clips and copy them to clipboard?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy All")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let combined = clips.map { $0.text }.joined(separator: "\n\n")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(combined, forType: .string)
            if AppPreferences.shared.playSound {
                NSSound(named: "Purr")?.play()
            }
        }
    }

    @objc func exportAllHistorySelected() {
        let clips = ClipboardMonitorService.shared.clips
        guard !clips.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Export All Clips?"
        alert.informativeText = "Would you like to export all \(clips.count) clippings to a file?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Export…")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let savePanel = NSSavePanel()
        savePanel.title = "Export BlueClip History"
        let dateStr = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .short,
            timeStyle: .none
        ).replacingOccurrences(of: "/", with: "-")
        savePanel.nameFieldStringValue = "BlueClip_Export_\(dateStr).txt"
        savePanel.allowedContentTypes = [.plainText, .json, .commaSeparatedText]
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            let ext = url.pathExtension.lowercased()
            let content: String
            if ext == "json" {
                content = StorageService.shared.exportClipsAsJSON(clips: clips) ?? ""
            } else if ext == "csv" {
                content = StorageService.shared.exportClipsAsCSV(clips: clips)
            } else {
                content = StorageService.shared.exportClipsAsText(clips: clips)
            }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    @objc func deleteAllHistorySelected() {
        let clips = ClipboardMonitorService.shared.clips
        guard !clips.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Delete All History?"
        alert.informativeText = "Are you sure you want to permanently clear all \(clips.count) clippings? " +
                                "This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardMonitorService.shared.clearAll()
            if AppPreferences.shared.playSound {
                NSSound(named: "Basso")?.play()
            }
        }
    }

    @objc func openPreferencesAction() {
        openPreferences()
    }

    @objc func openWebViewerSelected() {
        let prefs = AppPreferences.shared
        let emailParam = prefs.userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let tokenHash = prefs.sharewordHash
        let queryString = "account=\(emailParam)&hash=\(tokenHash)"

        let host = prefs.syncHost.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if !host.isEmpty, let targetURL = URL(string: "\(host)/?\(queryString)") {
            NSWorkspace.shared.open(targetURL)
        } else if let hubURL = URL(string: "http://127.0.0.1:8008/?\(queryString)") {
            NSWorkspace.shared.open(hubURL)
        }
    }

    @objc func openLocalWebViewerSelected() {
        let prefs = AppPreferences.shared
        let emailParam = prefs.userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let tokenHash = prefs.sharewordHash
        let queryString = "account=\(emailParam)&hash=\(tokenHash)"

        if let hubURL = URL(string: "http://127.0.0.1:8008/?\(queryString)") {
            NSWorkspace.shared.open(hubURL)
        }
    }

    @objc func quitAppSelected() {
        NSApplication.shared.terminate(nil)
    }
}
