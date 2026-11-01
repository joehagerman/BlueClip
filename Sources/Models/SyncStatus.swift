import Foundation

public enum SyncState: Equatable {
    case idle
    case syncing
    case success(Date)
    case failure(String)

    public var displayText: String {
        switch self {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing with private server…"
        case .success(let date):
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return "Synced (\(formatter.string(from: date)))"
        case .failure(let error):
            return "Sync warning: \(error)"
        }
    }
}

public struct SyncPayload: Codable {
    public let email: String
    public let shareword: String
    public let action: String
    public let device: String
    public let timestamp: String
    public let totalClips: Int
    public let clips: [ClipItem]

    public init(
        email: String,
        shareword: String,
        action: String = "merge",
        device: String,
        timestamp: String,
        totalClips: Int,
        clips: [ClipItem]
    ) {
        self.email = email
        self.shareword = shareword
        self.action = action
        self.device = device
        self.timestamp = timestamp
        self.totalClips = totalClips
        self.clips = clips
    }
}

public struct MergeServerResponse: Codable {
    public let status: String
    public let action: String?
    public let email: String?
    public let message: String?
    public let totalClips: Int?
    public let clips: [ClipItem]?
}
