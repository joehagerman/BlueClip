import Foundation
import Combine

public class NetworkSyncService: NSObject, ObservableObject, URLSessionDelegate {
    public static let shared = NetworkSyncService()

    @Published public var syncState: SyncState = .idle
    @Published public var lastSyncTime: Date?
    @Published public var lastSyncedItemCount: Int = 0
    @Published public var latencyMs: Int?
    @Published public var isServerReachable: Bool = false
    @Published public var activeEndpointLabel: String = "Local Hub (127.0.0.1:8008)"

    public var lastSyncTimeFormatted: String {
        guard let time = lastSyncTime else { return "Not synced yet" }
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: time)
    }

    private var syncTimer: AnyCancellable?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 15.0
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    override private init() {
        super.init()
        setupPeriodicTimer()
    }

    public func setupPeriodicTimer() {
        syncTimer?.cancel()
        let prefs = AppPreferences.shared
        guard prefs.syncEnabled && prefs.syncInterval > 0 else { return }

        syncTimer = Timer.publish(every: TimeInterval(prefs.syncInterval), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performSync()
            }
    }

    public func performSync(
        clips: [ClipItem]? = nil,
        isExplicitMerge: Bool = false,
        completion: ((Bool, String) -> Void)? = nil
    ) {
        let prefs = AppPreferences.shared
        guard prefs.syncEnabled else {
            completion?(false, "Sync is disabled.")
            return
        }

        let allClips = clips ?? StorageService.shared.loadClips()
        StorageService.shared.saveClips(allClips)

        let cleanHost = prefs.syncHost.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let cleanPath = prefs.syncPath.hasPrefix("/") ? prefs.syncPath : "/" + prefs.syncPath
        guard let url = URL(string: cleanHost + cleanPath) else {
            DispatchQueue.main.async {
                self.syncState = .failure("Invalid Sync URL")
                completion?(false, "Invalid URL")
            }
            return
        }

        let shouldMerge = isExplicitMerge || prefs.autoMerge
        let deviceName = Host.current().localizedName ?? "Mac"
        let payload = SyncPayload(
            email: prefs.userEmail,
            shareword: prefs.shareword,
            action: shouldMerge ? "merge" : "sync",
            device: deviceName,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            totalClips: allClips.count,
            clips: allClips
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let bodyData = try? encoder.encode(payload) else {
            completion?(false, "Encoding error")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BlueClip/2.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue(prefs.userEmail, forHTTPHeaderField: "X-User-Email")
        request.setValue(prefs.shareword, forHTTPHeaderField: "X-Shareword")
        if !prefs.shareword.isEmpty {
            request.setValue("Bearer \(prefs.shareword)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData

        DispatchQueue.main.async {
            self.syncState = .syncing
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        let task = urlSession.dataTask(with: request) { [weak self] data, response, _ in
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            DispatchQueue.main.async {
                self?.latencyMs = elapsed

                if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                    let now = Date()
                    self?.lastSyncTime = now
                    self?.isServerReachable = true

                    if shouldMerge, let data = data {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        if let mergeRes = try? decoder.decode(MergeServerResponse.self, from: data),
                           let remoteClips = mergeRes.clips, !remoteClips.isEmpty {
                            self?.applyMergedClips(remoteClips)
                        }
                    }

                    let finalCount = ClipboardMonitorService.shared.clips.count
                    self?.lastSyncedItemCount = finalCount
                    self?.activeEndpointLabel = prefs.syncHost
                    self?.syncState = .success(now)
                    let actionLabel = shouldMerge ? "Merged" : "Synced"
                    completion?(true, "\(actionLabel) \(finalCount) clips with server (\(elapsed)ms)")
                    return
                }

                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 401 {
                    let msg = "Incorrect shareword for \(prefs.userEmail)"
                    self?.syncState = .failure(msg)
                    completion?(false, msg)
                    return
                }

                // Fallback: If remote returned 404 or connection failed, attempt Local Hub or Local Merge
                self?.performLocalFallback(
                    allClips: allClips,
                    prefs: prefs,
                    shouldMerge: shouldMerge,
                    priorStatus: (response as? HTTPURLResponse)?.statusCode,
                    completion: completion
                )
            }
        }
        task.resume()
    }

    private func performLocalFallback(
        allClips: [ClipItem],
        prefs: AppPreferences,
        shouldMerge: Bool,
        priorStatus: Int?,
        completion: ((Bool, String) -> Void)?
    ) {
        // 1. Try local server at http://127.0.0.1:8008/api/clipboard-sync if remote failed
        if prefs.syncHost != "http://127.0.0.1:8008", let localURL = URL(string: "http://127.0.0.1:8008/api/clipboard-sync") {
            var localReq = URLRequest(url: localURL)
            localReq.httpMethod = "POST"
            localReq.timeoutInterval = 2.0
            localReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            localReq.setValue(prefs.userEmail, forHTTPHeaderField: "X-User-Email")
            localReq.setValue(prefs.shareword, forHTTPHeaderField: "X-Shareword")

            let payload = SyncPayload(
                email: prefs.userEmail,
                shareword: prefs.shareword,
                action: shouldMerge ? "merge" : "sync",
                device: Host.current().localizedName ?? "Mac",
                timestamp: ISO8601DateFormatter().string(from: Date()),
                totalClips: allClips.count,
                clips: allClips
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            localReq.httpBody = try? encoder.encode(payload)

            let localTask = URLSession.shared.dataTask(with: localReq) { [weak self] data, response, _ in
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    DispatchQueue.main.async {
                        let now = Date()
                        self?.lastSyncTime = now
                        self?.isServerReachable = true
                        if shouldMerge, let data = data {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            if let mergeRes = try? decoder.decode(MergeServerResponse.self, from: data),
                               let remoteClips = mergeRes.clips, !remoteClips.isEmpty {
                                self?.applyMergedClips(remoteClips)
                            }
                        }
                        let finalCount = ClipboardMonitorService.shared.clips.count
                        self?.lastSyncedItemCount = finalCount
                        self?.activeEndpointLabel = "Local Hub (127.0.0.1:8008)"
                        self?.syncState = .success(now)
                        let note = priorStatus == 404 ? " (Remote 404)" : ""
                        completion?(true, "Merged \(finalCount) clips with Local Hub\(note)")
                    }
                    return
                }

                // 2. Direct disk merge fallback if local server wasn't running
                DispatchQueue.main.async {
                    self?.executeDirectDiskMerge(
                        allClips: allClips,
                        prefs: prefs,
                        priorStatus: priorStatus,
                        completion: completion
                    )
                }
            }
            localTask.resume()
            return
        }

        executeDirectDiskMerge(
            allClips: allClips,
            prefs: prefs,
            priorStatus: priorStatus,
            completion: completion
        )
    }

    private func executeDirectDiskMerge(
        allClips: [ClipItem],
        prefs: AppPreferences,
        priorStatus: Int?,
        completion: ((Bool, String) -> Void)?
    ) {
        let merged = StorageService.shared.mergeClipsLocally(
            incoming: allClips,
            email: prefs.userEmail,
            shareword: prefs.shareword
        )
        ClipboardMonitorService.shared.clips = merged
        ClipboardMonitorService.shared.enforceMaxClips()

        let now = Date()
        self.lastSyncTime = now
        self.isServerReachable = false
        self.lastSyncedItemCount = merged.count
        self.syncState = .success(now)

        let reason = priorStatus == 404 ? " (Remote server returned 404)" : " (Local Store)"
        completion?(true, "Unified \(merged.count) clips across devices\(reason)")
    }

    private func applyMergedClips(_ remoteClips: [ClipItem]) {
        let monitor = ClipboardMonitorService.shared
        var clipMap: [String: ClipItem] = [:]

        for clip in monitor.clips {
            clipMap[clip.text] = clip
        }

        for rClip in remoteClips {
            if let existing = clipMap[rClip.text] {
                let pinned = existing.isPinned || rClip.isPinned
                let newest = max(existing.timestamp, rClip.timestamp)
                let resolvedKeywords = !rClip.keywords.isEmpty ? rClip.keywords : existing.keywords
                clipMap[rClip.text] = ClipItem(
                    id: existing.id,
                    text: rClip.text,
                    timestamp: newest,
                    appBundleId: rClip.appBundleId ?? existing.appBundleId,
                    appName: rClip.appName ?? existing.appName,
                    isPinned: pinned,
                    keywords: resolvedKeywords
                )
            } else {
                clipMap[rClip.text] = rClip
            }
        }

        var unified = Array(clipMap.values)
        unified.sort { (firstClip, secondClip) in
            if firstClip.isPinned != secondClip.isPinned {
                return firstClip.isPinned && !secondClip.isPinned
            }
            return firstClip.timestamp > secondClip.timestamp
        }

        monitor.clips = unified
        monitor.enforceMaxClips()
        StorageService.shared.saveClips(monitor.clips)
    }

    public func testConnection(completion: @escaping (Bool, String) -> Void) {
        let prefs = AppPreferences.shared
        let cleanHost = prefs.syncHost.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: cleanHost) else {
            completion(false, "Invalid Host URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0

        let start = CFAbsoluteTimeGetCurrent()
        let task = urlSession.dataTask(with: request) { [weak self] _, response, error in
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            DispatchQueue.main.async {
                self?.latencyMs = elapsed
                if let error = error {
                    self?.isServerReachable = false
                    completion(false, "Connection error: \(error.localizedDescription)")
                } else if let httpRes = response as? HTTPURLResponse {
                    self?.isServerReachable = true
                    completion(true, "Server online (\(elapsed)ms)")
                } else {
                    completion(false, "Unknown response")
                }
            }
        }
        task.resume()
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let host = challenge.protectionSpace.host
        if host.contains("nip.io") || host == "localhost" || host == "127.0.0.1" || host.split(separator: ".").count == 4 {
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
