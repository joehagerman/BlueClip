import SwiftUI
import AppKit

@main
struct BlueClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        if CommandLine.arguments.contains("--cli") || CommandLine.arguments.contains("-c") {
            runCLIMode()
            exit(0)
        }
    }

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }

    private func runCLIMode() {
        print("""
        ================================================================================
        📎 BlueClip • Next-Generation macOS Clipboard Manager with Private Cloud Sync
        ================================================================================
        """)
        let clips = StorageService.shared.loadClips()
        print("  ▸ Stored Clips:       \(clips.count)")
        print("  ▸ Sync Target:        \(AppPreferences.shared.syncHost)")
        print("  ▸ Auto-Paste:         \(AppPreferences.shared.autoPaste ? "Enabled" : "Disabled")")
        print("  ▸ Blacklisted Apps:   \(AppPreferences.shared.ignoredApps.filter { $0.isEnabled }.count) active")
        print("--------------------------------------------------------------------------------")
        for (index, clip) in clips.prefix(10).enumerated() {
            let shortcut = index < 10 ? "⌘\(index)" : "   "
            print("  [\(shortcut)] (\(clip.timeAgo)) \(clip.preview(limit: 60))")
        }
        print("================================================================================\n")
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public static var sharedInstance: AppDelegate?
    var statusItem: NSStatusItem?
    var statusMenu = NSMenu()
    var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.sharedInstance = self
        // Run as background menu bar accessory app
        NSApp.setActivationPolicy(.accessory)

        // Setup Menu Bar Status Item with native NSMenu
        setupStatusBar()

        // Initial sync check with private network
        if AppPreferences.shared.syncEnabled {
            NetworkSyncService.shared.performSync(clips: ClipboardMonitorService.shared.clips)
        }

        // Open preferences if requested via launch argument
        if CommandLine.arguments.contains("--preferences") || CommandLine.arguments.contains("-p") {
            openPreferences()
        }
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBarIcon()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIconChangedNotification),
            name: NSNotification.Name("BlueClipMenuBarIconChanged"),
            object: nil
        )

        statusMenu.delegate = self
        statusMenu.autoenablesItems = false
        statusItem?.menu = statusMenu
    }

    @objc func handleIconChangedNotification() {
        updateStatusBarIcon()
    }

    @objc func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        let prefs = AppPreferences.shared
        let iconSize: CGFloat = 18
        let isBlue = prefs.blueMenuBarIcon
        let emoji = prefs.currentEmoji

        let img = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { rect in
            let font = NSFont.systemFont(ofSize: 14)
            let str = NSAttributedString(string: emoji, attributes: [.font: font])
            let strSize = str.size()
            let drawPoint = CGPoint(
                x: (rect.width - strSize.width) / 2.0,
                y: (rect.height - strSize.height) / 2.0
            )
            str.draw(at: drawPoint)

            if isBlue {
                NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).set()
                rect.fill(using: .sourceAtop)
            } else {
                NSColor.white.set()
                rect.fill(using: .sourceAtop)
            }
            return true
        }

        img.isTemplate = !isBlue
        button.image = img
        button.toolTip = "BlueClip — Clipboard History (\(emoji))"
    }

    // MARK: - NSMenuDelegate Dynamic Population

    func menuNeedsUpdate(_ menu: NSMenu) {
        populateDynamicMenu(menu)
    }

    func openPreferences(tab: PreferencesView.Tab = .general) {
        if let win = preferencesWindow {
            win.contentView = NSHostingView(rootView: PreferencesView(selectedTab: tab))
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 470),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Preferences"
        window.contentView = NSHostingView(rootView: PreferencesView(selectedTab: tab))
        window.isReleasedWhenClosed = false

        self.preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
