import Foundation

public struct ClipItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let text: String
    public let timestamp: Date
    public let charCount: Int
    public let appBundleId: String?
    public let appName: String?
    public var isPinned: Bool
    public var keywords: [String]

    public init(
        id: UUID = UUID(),
        text: String,
        timestamp: Date = Date(),
        appBundleId: String? = nil,
        appName: String? = nil,
        isPinned: Bool = false,
        keywords: [String] = []
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.charCount = text.count
        self.appBundleId = appBundleId
        self.appName = appName
        self.isPinned = isPinned
        self.keywords = keywords
    }

    enum CodingKeys: String, CodingKey {
        case id, text, timestamp, charCount, appBundleId, appName, isPinned, keywords
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.text = try container.decode(String.self, forKey: .text)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.charCount = try container.decodeIfPresent(Int.self, forKey: .charCount) ?? self.text.count
        self.appBundleId = try container.decodeIfPresent(String.self, forKey: .appBundleId)
        self.appName = try container.decodeIfPresent(String.self, forKey: .appName)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
    }

    public func preview(limit: Int = 65) -> String {
        let singleLine = text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)

        if singleLine.count <= limit {
            return singleLine
        }
        let index = singleLine.index(singleLine.startIndex, offsetBy: limit)
        return String(singleLine[..<index]) + "…"
    }

    public var timeAgo: String {
        let seconds = Int(-timestamp.timeIntervalSinceNow)
        if seconds < 5 { return "Just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

public struct IgnoredApp: Identifiable, Codable, Equatable {
    public var id: String { bundleId }
    public var name: String
    public var bundleId: String
    public var isEnabled: Bool

    public init(name: String, bundleId: String, isEnabled: Bool = true) {
        self.name = name
        self.bundleId = bundleId
        self.isEnabled = isEnabled
    }
}
