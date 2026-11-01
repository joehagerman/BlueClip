import Foundation

public class StorageService {
    public static let shared = StorageService()

    private let fileManager = FileManager.default
    private let appSupportDir: URL
    private let clipsFile: URL
    private let syncCacheFile: URL
    private let localCacheFile: URL

    private init() {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let base = urls.first!.appendingPathComponent("BlueClip", isDirectory: true)
        self.appSupportDir = base
        self.clipsFile = base.appendingPathComponent("clips.json")
        self.syncCacheFile = base.appendingPathComponent("clipboard_history.json")
        self.localCacheFile = base.appendingPathComponent("clipboard_history_cache.json")

        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    }

    public func loadClips() -> [ClipItem] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Primary: Load active clips.json
        if fileManager.fileExists(atPath: clipsFile.path),
           let data = try? Data(contentsOf: clipsFile),
           let clips = try? decoder.decode([ClipItem].self, from: data),
           !clips.isEmpty {
            return clips
        }

        // Fallback 1: Local cache backup
        if fileManager.fileExists(atPath: localCacheFile.path),
           let cacheData = try? Data(contentsOf: localCacheFile) {
            if let clips = try? decoder.decode([ClipItem].self, from: cacheData), !clips.isEmpty {
                return clips
            }
            if let payload = try? decoder.decode(SyncPayload.self, from: cacheData), !payload.clips.isEmpty {
                return payload.clips
            }
        }

        // Fallback 2: Sync cache file
        if fileManager.fileExists(atPath: syncCacheFile.path),
           let syncData = try? Data(contentsOf: syncCacheFile) {
            if let payload = try? decoder.decode(SyncPayload.self, from: syncData), !payload.clips.isEmpty {
                return payload.clips
            }
            if let clips = try? decoder.decode([ClipItem].self, from: syncData), !clips.isEmpty {
                return clips
            }
        }

        return []
    }

    public func saveClips(_ clips: [ClipItem]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(clips) else { return }

        // 1. Primary active store
        try? data.write(to: clipsFile, options: .atomic)
        // 2. Permanent local cache backup
        try? data.write(to: localCacheFile, options: .atomic)
        // 3. Sync cache
        try? data.write(to: syncCacheFile, options: .atomic)
    }

    public func exportClipsAsJSON(clips: [ClipItem]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(clips),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }

    public func exportClipsAsText(clips: [ClipItem]) -> String {
        var output = "# BlueClip Export — \(Date())\n\n"
        for (index, clip) in clips.enumerated() {
            output += "--------------------------------------------------\n"
            output += "[\(index + 1)] Date: \(clip.formattedDate) | App: \(clip.appName ?? "Unknown") | Chars: \(clip.charCount)\n"
            output += "--------------------------------------------------\n"
            output += clip.text + "\n\n"
        }
        return output
    }

    public func exportClipsAsCSV(clips: [ClipItem]) -> String {
        var csv = "Index,Date,App,Length,Text\n"
        for (index, clip) in clips.enumerated() {
            let safeText = clip.text
                .replacingOccurrences(of: "\"", with: "\"\"")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            let safeApp = (clip.appName ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(index + 1),\"\(clip.formattedDate)\",\"\(safeApp)\",\(clip.charCount),\"\(safeText)\"\n"
        }
        return csv
    }

    @discardableResult
    public func mergeClipsLocally(incoming: [ClipItem], email: String, shareword: String) -> [ClipItem] {
        var existing = loadClips()

        let cleanEmail = email.replacingOccurrences(of: "/", with: "_")
        let accountFile = appSupportDir.appendingPathComponent("clipboard_history_\(cleanEmail).json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: accountFile),
           let payload = try? decoder.decode(SyncPayload.self, from: data) {
            existing.append(contentsOf: payload.clips)
        }

        var clipMap: [String: ClipItem] = [:]
        for clip in existing {
            clipMap[clip.text] = clip
        }

        for clip in incoming {
            if let prior = clipMap[clip.text] {
                let pinned = prior.isPinned || clip.isPinned
                let newest = max(prior.timestamp, clip.timestamp)
                let resolvedKeywords = !clip.keywords.isEmpty ? clip.keywords : prior.keywords
                clipMap[clip.text] = ClipItem(
                    id: prior.id,
                    text: clip.text,
                    timestamp: newest,
                    appBundleId: clip.appBundleId ?? prior.appBundleId,
                    appName: clip.appName ?? prior.appName,
                    isPinned: pinned,
                    keywords: resolvedKeywords
                )
            } else {
                clipMap[clip.text] = clip
            }
        }

        var unified = Array(clipMap.values)
        unified.sort { (firstClip, secondClip) in
            if firstClip.isPinned != secondClip.isPinned {
                return firstClip.isPinned && !secondClip.isPinned
            }
            return firstClip.timestamp > secondClip.timestamp
        }

        saveClips(unified)

        let payload = SyncPayload(
            email: email,
            shareword: shareword,
            action: "merge",
            device: Host.current().localizedName ?? "Mac",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            totalClips: unified.count,
            clips: unified
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let encData = try? encoder.encode(payload) {
            try? encData.write(to: accountFile, options: .atomic)
            try? encData.write(to: syncCacheFile, options: .atomic)
            try? encData.write(to: localCacheFile, options: .atomic)
        }

        return unified
    }
}
