import Foundation
import Combine
import CryptoKit

public class AppPreferences: ObservableObject {
    public static let shared = AppPreferences()

    private let defaults = UserDefaults.standard

    // Storage Keys
    private let kMaxClips = "BlueClip_MaxClips"
    private let kMaxSnippetLength = "BlueClip_MaxSnippetLength"
    private let kAutoPaste = "BlueClip_AutoPaste"
    private let kPlaySound = "BlueClip_PlaySound"
    private let kLaunchAtLogin = "BlueClip_LaunchAtLogin"
    private let kBlueMenuBarIcon = "BlueClip_BlueMenuBarIcon"
    private let kIgnoredApps = "BlueClip_IgnoredApps"
    private let kSyncEnabled = "BlueClip_SyncEnabled"
    private let kSyncHost = "BlueClip_SyncHost"
    private let kSyncPath = "BlueClip_SyncPath"
    private let kUserEmail = "BlueClip_UserEmail"
    private let kShareword = "BlueClip_Shareword"
    private let kSyncOnCopy = "BlueClip_SyncOnCopy"
    private let kSyncInterval = "BlueClip_SyncInterval"
    private let kAutoMerge = "BlueClip_AutoMerge"
    private let kSortMode = "BlueClip_SortMode"
    private let kChronoDisplayLimit = "BlueClip_ChronoDisplayLimit"
    private let kTagSortMode = "BlueClip_TagSortMode"
    private let kTagDisplayLimit = "BlueClip_TagDisplayLimit"

    public enum SortMode: String, CaseIterable, Codable {
        case chrono
        case keyword
    }

    public enum TagSortMode: String, CaseIterable, Codable {
        case mostFrequent
        case hottest
        case all

        public var title: String {
            switch self {
            case .mostFrequent: return "Most Frequent"
            case .hottest: return "Hottest"
            case .all: return "All (A–Z)"
            }
        }
    }

    @Published public var sortMode: SortMode {
        didSet { defaults.set(sortMode.rawValue, forKey: kSortMode) }
    }

    @Published public var chronoDisplayLimit: Int {
        didSet { defaults.set(chronoDisplayLimit, forKey: kChronoDisplayLimit) }
    }

    @Published public var tagSortMode: TagSortMode {
        didSet { defaults.set(tagSortMode.rawValue, forKey: kTagSortMode) }
    }

    @Published public var tagDisplayLimit: Int {
        didSet { defaults.set(tagDisplayLimit, forKey: kTagDisplayLimit) }
    }

    @Published public var maxClips: Int {
        didSet { defaults.set(maxClips, forKey: kMaxClips) }
    }

    @Published public var maxSnippetLength: Int {
        didSet { defaults.set(maxSnippetLength, forKey: kMaxSnippetLength) }
    }

    @Published public var autoPaste: Bool {
        didSet { defaults.set(autoPaste, forKey: kAutoPaste) }
    }

    @Published public var playSound: Bool {
        didSet { defaults.set(playSound, forKey: kPlaySound) }
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: kLaunchAtLogin) }
    }

    @Published public var blueMenuBarIcon: Bool {
        didSet {
            defaults.set(blueMenuBarIcon, forKey: kBlueMenuBarIcon)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("BlueClipMenuBarIconChanged"), object: nil)
            }
        }
    }

    @Published public var ignoredApps: [IgnoredApp] {
        didSet {
            if let data = try? JSONEncoder().encode(ignoredApps) {
                defaults.set(data, forKey: kIgnoredApps)
            }
        }
    }

    @Published public var syncEnabled: Bool {
        didSet { defaults.set(syncEnabled, forKey: kSyncEnabled) }
    }

    @Published public var syncHost: String {
        didSet { defaults.set(syncHost, forKey: kSyncHost) }
    }

    @Published public var syncPath: String {
        didSet { defaults.set(syncPath, forKey: kSyncPath) }
    }

    @Published public var userEmail: String {
        didSet { defaults.set(userEmail, forKey: kUserEmail) }
    }

    @Published public var shareword: String {
        didSet { defaults.set(shareword, forKey: kShareword) }
    }

    @Published public var syncOnCopy: Bool {
        didSet { defaults.set(syncOnCopy, forKey: kSyncOnCopy) }
    }

    @Published public var syncInterval: Int {
        didSet { defaults.set(syncInterval, forKey: kSyncInterval) }
    }

    @Published public var autoMerge: Bool {
        didSet { defaults.set(autoMerge, forKey: kAutoMerge) }
    }

    public static let easterEggEmojis = ["📌", "🚀", "💎", "📎", "💙", "⚡️", "⭐️", "🎯"]

    @Published public var emojiIndex: Int {
        didSet {
            defaults.set(emojiIndex, forKey: "BlueClip_EmojiIndex")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("BlueClipMenuBarIconChanged"), object: nil)
            }
        }
    }

    public var currentEmoji: String {
        Self.easterEggEmojis[emojiIndex % Self.easterEggEmojis.count]
    }

    public func cycleEasterEggEmoji() {
        emojiIndex = (emojiIndex + 1) % Self.easterEggEmojis.count
    }

    public init() {
        self.maxClips = defaults.object(forKey: kMaxClips) != nil ? defaults.integer(forKey: kMaxClips) : 80
        self.maxSnippetLength = defaults.object(forKey: kMaxSnippetLength) != nil ? defaults.integer(forKey: kMaxSnippetLength) : 65
        self.autoPaste = defaults.bool(forKey: kAutoPaste) // Default false to avoid device control prompts
        self.playSound = defaults.object(forKey: kPlaySound) != nil ? defaults.bool(forKey: kPlaySound) : true
        self.launchAtLogin = defaults.bool(forKey: kLaunchAtLogin)
        self.blueMenuBarIcon = defaults.object(forKey: kBlueMenuBarIcon) != nil ? defaults.bool(forKey: kBlueMenuBarIcon) : true
        self.emojiIndex = defaults.integer(forKey: "BlueClip_EmojiIndex")

        // Sync defaults
        self.syncEnabled = defaults.object(forKey: kSyncEnabled) != nil ? defaults.bool(forKey: kSyncEnabled) : true
        self.syncHost = defaults.string(forKey: kSyncHost) ?? "http://127.0.0.1:8008"
        self.syncPath = defaults.string(forKey: kSyncPath) ?? "/api/clipboard-sync"

        // Email & Autogenerated Shareword (##colorANIMAL)
        let savedEmail = defaults.string(forKey: kUserEmail) ?? defaults.string(forKey: "BlueClip_AppleId")
        self.userEmail = savedEmail ?? "\(NSUserName())@icloud.com"

        let savedShareword = defaults.string(forKey: kShareword) ?? defaults.string(forKey: "BlueClip_SyncToken")
        if let existing = savedShareword, !existing.isEmpty && !existing.hasPrefix("##") {
            self.shareword = existing
        } else {
            let generated = Self.generateRandomShareword()
            self.shareword = generated
            defaults.set(generated, forKey: kShareword)
        }

        self.syncOnCopy = defaults.object(forKey: kSyncOnCopy) != nil ? defaults.bool(forKey: kSyncOnCopy) : true
        self.syncInterval = defaults.object(forKey: kSyncInterval) != nil ? defaults.integer(forKey: kSyncInterval) : 60
        self.autoMerge = defaults.object(forKey: kAutoMerge) != nil ? defaults.bool(forKey: kAutoMerge) : true

        if let savedSort = defaults.string(forKey: kSortMode), let mode = SortMode(rawValue: savedSort) {
            self.sortMode = mode
        } else {
            self.sortMode = .chrono
        }

        self.chronoDisplayLimit = defaults.object(forKey: kChronoDisplayLimit) != nil
            ? defaults.integer(forKey: kChronoDisplayLimit) : 15

        if let savedTagSort = defaults.string(forKey: kTagSortMode),
           let mode = TagSortMode(rawValue: savedTagSort) {
            self.tagSortMode = mode
        } else {
            self.tagSortMode = .mostFrequent
        }

        self.tagDisplayLimit = defaults.object(forKey: kTagDisplayLimit) != nil
            ? defaults.integer(forKey: kTagDisplayLimit) : 10

        // Default ignored apps
        if let data = defaults.data(forKey: kIgnoredApps),
           let decoded = try? JSONDecoder().decode([IgnoredApp].self, from: data) {
            self.ignoredApps = decoded
        } else {
            self.ignoredApps = [
                IgnoredApp(name: "Keychain Access", bundleId: "com.apple.keychainaccess", isEnabled: true),
                IgnoredApp(name: "Apple Passwords", bundleId: "com.apple.Passwords", isEnabled: true),
                IgnoredApp(name: "1Password", bundleId: "com.1password.1password", isEnabled: true),
                IgnoredApp(name: "1Password 7", bundleId: "com.agilebits.onepassword7", isEnabled: true),
                IgnoredApp(name: "Bitwarden", bundleId: "com.bitwarden.desktop", isEnabled: true),
                IgnoredApp(name: "KeepassXC", bundleId: "org.keepassxc.keepassxc", isEnabled: true),
                IgnoredApp(name: "Enpass", bundleId: "in.sinew.Enpass-Desktop", isEnabled: true)
            ]
        }
    }

    public static func generateRandomShareword() -> String {
        let number = Int.random(in: 10...99)
        let colors = ["amber", "blue", "red", "green", "gold", "silver", "teal", "ruby", "coral", "copper", "bronze"]
        let animals = [
            "tigers", "eagles", "lions", "bears", "falcons", "hawks", "wolves", "foxes", "otters", "dolphins"
        ]
        let chosenColor = colors.randomElement() ?? "amber"
        let chosenAnimal = animals.randomElement() ?? "tigers"
        return "\(number) \(chosenColor) \(chosenAnimal)"
    }

    public static func normalizeShareword(_ input: String) -> String {
        let lower = input.lowercased()
        let allowed = CharacterSet.alphanumerics
        let cleaned = lower.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let str = String(cleaned)
        var tokens = str.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        func stem(_ word: String) -> String {
            if word.hasSuffix("ies") && word.count > 4 {
                return String(word.dropLast(3)) + "y"
            }
            if word.hasSuffix("ves") && word.count > 4 {
                return String(word.dropLast(3)) + "f"
            }
            if word.hasSuffix("es") && word.count > 3 &&
               (word.hasSuffix("xes") || word.hasSuffix("ses") || word.hasSuffix("ches") || word.hasSuffix("shes")) {
                return String(word.dropLast(2))
            }
            if word.hasSuffix("s") && !word.hasSuffix("ss") && word.count > 2 {
                return String(word.dropLast(1))
            }
            return word
        }

        tokens = tokens.map { stem($0) }
        return tokens.joined()
    }

    public static func matchesShareword(_ first: String, _ second: String) -> Bool {
        let normFirst = normalizeShareword(first)
        let normSecond = normalizeShareword(second)
        return !normFirst.isEmpty && normFirst == normSecond
    }

    public var sharewordHash: String {
        let norm = Self.normalizeShareword(shareword)
        guard !norm.isEmpty else { return "" }
        let digest = SHA256.hash(data: Data(norm.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func isBundleIgnored(_ bundleId: String?) -> Bool {
        guard let bundleId = bundleId?.lowercased() else { return false }
        return ignoredApps.contains { app in
            app.isEnabled && (app.bundleId.lowercased() == bundleId || bundleId.contains(app.bundleId.lowercased()))
        }
    }
}
