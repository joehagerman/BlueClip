import AppKit
import Combine

public class ClipboardMonitorService: ObservableObject {
    public static let shared = ClipboardMonitorService()

    @Published public var clips: [ClipItem] = []
    @Published public var lastCopiedText: String = ""

    private var pasteboardTimer: AnyCancellable?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general

    private init() {
        self.clips = StorageService.shared.loadClips()
        self.lastChangeCount = pasteboard.changeCount
        ensureKeywordsPopulated()
        startMonitoring()
    }

    public func startMonitoring() {
        pasteboardTimer?.cancel()
        pasteboardTimer = Timer.publish(every: 0.35, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPasteboard()
            }
    }

    public func stopMonitoring() {
        pasteboardTimer?.cancel()
    }

    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        let prefs = AppPreferences.shared

        // Inspect frontmost application
        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleId = frontApp?.bundleIdentifier
        let appName = frontApp?.localizedName

        // Ignore self-copy (avoid re-recording when user clicks to paste from BlueClip)
        if bundleId == Bundle.main.bundleIdentifier || appName == "BlueClip" {
            return
        }

        // Check blacklist
        if prefs.isBundleIgnored(bundleId) {
            return
        }

        // Extract string content
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Avoid duplicate spam if identical to top clip
        if let top = clips.first, top.text == text {
            return
        }

        // Generate AFM keywords for the clip
        let keywords = AFMKeywordService.shared.generateKeywords(for: text) { [weak self] refined in
            self?.updateKeywords(for: text, keywords: refined)
        }

        // If it already exists lower in the history, remove old duplicate and bring to top
        if let existingIdx = clips.firstIndex(where: { $0.text == text }) {
            let existing = clips.remove(at: existingIdx)
            let updated = ClipItem(
                id: existing.id,
                text: text,
                timestamp: Date(),
                appBundleId: bundleId ?? existing.appBundleId,
                appName: appName ?? existing.appName,
                isPinned: existing.isPinned,
                keywords: keywords.isEmpty ? existing.keywords : keywords
            )
            clips.insert(updated, at: 0)
        } else {
            let newClip = ClipItem(
                text: text,
                timestamp: Date(),
                appBundleId: bundleId,
                appName: appName,
                isPinned: false,
                keywords: keywords
            )
            clips.insert(newClip, at: 0)
        }

        // Enforce maximum clips limit
        enforceMaxClips()

        // Persist locally
        StorageService.shared.saveClips(clips)
        self.lastCopiedText = text

        // Subtle sound feedback
        if prefs.playSound {
            NSSound(named: "Tink")?.play()
        }

        // Automatic Network Sync
        if prefs.syncEnabled && prefs.syncOnCopy {
            NetworkSyncService.shared.performSync(clips: clips)
        }
    }

    public func enforceMaxClips() {
        let limit = AppPreferences.shared.maxClips
        if clips.count > limit {
            // Keep pinned clips if possible
            let pinned = clips.filter { $0.isPinned }
            let unpinned = clips.filter { !$0.isPinned }
            let allowedUnpinned = max(0, limit - pinned.count)
            clips = pinned + Array(unpinned.prefix(allowedUnpinned))
            // Re-sort chronologically with pinned first if desired, or pure timestamp
            clips.sort { (firstClip, secondClip) in
                if firstClip.isPinned != secondClip.isPinned {
                    return firstClip.isPinned && !secondClip.isPinned
                }
                return firstClip.timestamp > secondClip.timestamp
            }
        }
    }

    public func selectClip(_ clip: ClipItem, autoPaste: Bool) {
        pasteboard.clearContents()
        pasteboard.setString(clip.text, forType: .string)
        self.lastChangeCount = pasteboard.changeCount

        if AppPreferences.shared.playSound {
            NSSound(named: "Pop")?.play()
        }

        if autoPaste {
            AutoPasteService.simulatePaste()
        }
    }

    public func deleteClip(id: UUID) {
        clips.removeAll { $0.id == id }
        StorageService.shared.saveClips(clips)
        if AppPreferences.shared.syncEnabled {
            NetworkSyncService.shared.performSync(clips: clips)
        }
    }

    public func clearAll() {
        // Retain pinned clips
        clips.removeAll { !$0.isPinned }
        StorageService.shared.saveClips(clips)
        if AppPreferences.shared.syncEnabled {
            NetworkSyncService.shared.performSync(clips: clips)
        }
    }

    public func togglePin(id: UUID) {
        if let idx = clips.firstIndex(where: { $0.id == id }) {
            clips[idx].isPinned.toggle()
            StorageService.shared.saveClips(clips)
        }
    }

    public func updateKeywords(for text: String, keywords: [String]) {
        guard let idx = clips.firstIndex(where: { $0.text == text }) else { return }
        clips[idx].keywords = keywords
        StorageService.shared.saveClips(clips)
    }

    public func ensureKeywordsPopulated() {
        var didUpdate = false
        for index in 0..<clips.count {
            if clips[index].keywords.isEmpty {
                clips[index].keywords = AFMKeywordService.shared.extractOnDeviceKeywords(from: clips[index].text)
                didUpdate = true
            }
        }
        if didUpdate {
            StorageService.shared.saveClips(clips)
        }
    }
}
