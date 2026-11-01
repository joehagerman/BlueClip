import AppKit
import SwiftUI

extension AppDelegate {
    // MARK: - Dynamic Menu Population

    func populateDynamicMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let prefs = AppPreferences.shared
        let isChrono = prefs.sortMode == .chrono

        // 1. Sort Option & Subsettings
        buildSortHeaderMenuItems(into: menu, prefs: prefs, isChrono: isChrono)
        menu.addItem(NSMenuItem.separator())

        // 2. Header instruction item
        let headerTitle = isChrono
            ? "Select the clip you want to add to your clipboard"
            : "Select a clip grouped by AFM keyword"
        let headerItem = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        // 3. Build Clips list according to sort mode
        if isChrono {
            buildClipMenuItems(into: menu)
        } else {
            buildKeywordGroupedMenuItems(into: menu)
        }
        menu.addItem(NSMenuItem.separator())

        // 4. Action items
        buildActionMenuItems(into: menu)
    }

    private func buildSortHeaderMenuItems(into menu: NSMenu, prefs: AppPreferences, isChrono: Bool) {
        // Main Sort Toggle Item
        let sortTitle = isChrono
            ? "Sort: Chronological (Most Recent)"
            : "Sort: Keywords (\(prefs.tagSortMode.title))"
        let sortItem = NSMenuItem(title: sortTitle, action: #selector(toggleSortModeSelected), keyEquivalent: "")
        sortItem.target = self
        sortItem.image = NSImage(
            systemSymbolName: isChrono ? "clock.arrow.circlepath" : "tag.fill",
            accessibilityDescription: "Sort Mode"
        )

        let sortSubmenu = NSMenu(title: "Sort Order")
        let chronoSub = NSMenuItem(
            title: "Chronological Order (Most Recent)",
            action: #selector(setChronoSortSelected),
            keyEquivalent: ""
        )
        chronoSub.target = self
        chronoSub.state = isChrono ? .on : .off
        sortSubmenu.addItem(chronoSub)

        let keywordSub = NSMenuItem(
            title: "Group by Keywords (AFM)",
            action: #selector(setKeywordSortSelected),
            keyEquivalent: ""
        )
        keywordSub.target = self
        keywordSub.state = !isChrono ? .on : .off
        sortSubmenu.addItem(keywordSub)

        sortItem.submenu = sortSubmenu
        menu.addItem(sortItem)

        // Subsetting Quick Selectors directly in menu
        if isChrono {
            buildChronoLimitMenuItem(into: menu, prefs: prefs)
        } else {
            buildKeywordSortMenuItems(into: menu, prefs: prefs)
        }
    }

    private func buildChronoLimitMenuItem(into menu: NSMenu, prefs: AppPreferences) {
        let limitText = prefs.chronoDisplayLimit == 0 ? "All" : "\(prefs.chronoDisplayLimit)"
        let limitItem = NSMenuItem(title: "Show Recent: \(limitText) Clips ▾", action: nil, keyEquivalent: "")
        limitItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Display Limit")
        let limitMenu = NSMenu(title: "Display Limit")
        for limit in [5, 10, 15, 25, 50, 0] {
            let label = limit == 0 ? "Show All Clips" : "Show \(limit) Clips"
            let sub = NSMenuItem(title: label, action: #selector(setChronoLimitFromMenuItem(_:)), keyEquivalent: "")
            sub.target = self
            sub.tag = limit
            sub.state = (prefs.chronoDisplayLimit == limit) ? .on : .off
            limitMenu.addItem(sub)
        }
        limitItem.submenu = limitMenu
        menu.addItem(limitItem)
    }

    private func buildKeywordSortMenuItems(into menu: NSMenu, prefs: AppPreferences) {
        let orderItem = NSMenuItem(title: "Tag Order: \(prefs.tagSortMode.title) ▾", action: nil, keyEquivalent: "")
        orderItem.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Tag Order")
        let orderMenu = NSMenu(title: "Tag Order")
        for mode in AppPreferences.TagSortMode.allCases {
            let sub = NSMenuItem(
                title: mode.title,
                action: #selector(setTagSortModeFromMenuItem(_:)),
                keyEquivalent: ""
            )
            sub.target = self
            sub.representedObject = mode
            sub.state = (prefs.tagSortMode == mode) ? .on : .off
            orderMenu.addItem(sub)
        }
        orderItem.submenu = orderMenu
        menu.addItem(orderItem)

        let tagCountText = prefs.tagDisplayLimit == 0 ? "All Tags" : "Top \(prefs.tagDisplayLimit)"
        let countItem = NSMenuItem(title: "Show Tags: \(tagCountText) ▾", action: nil, keyEquivalent: "")
        countItem.image = NSImage(
            systemSymbolName: "line.3.horizontal.decrease.circle",
            accessibilityDescription: "Tag Quantity"
        )
        let countMenu = NSMenu(title: "Show Tags")
        for limit in [5, 10, 15, 25, 0] {
            let label = limit == 0 ? "All Tags" : "Top \(limit) Tags"
            let sub = NSMenuItem(title: label, action: #selector(setTagLimitFromMenuItem(_:)), keyEquivalent: "")
            sub.target = self
            sub.tag = limit
            sub.state = (prefs.tagDisplayLimit == limit) ? .on : .off
            countMenu.addItem(sub)
        }
        countItem.submenu = countMenu
        menu.addItem(countItem)
    }

    private func buildClipMenuItems(into menu: NSMenu) {
        let monitor = ClipboardMonitorService.shared
        let clips = monitor.clips
        let prefs = AppPreferences.shared
        let snippetLimit = prefs.maxSnippetLength

        if clips.isEmpty {
            let emptyItem = NSMenuItem(title: "No clippings recorded yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        let displayLimit = prefs.chronoDisplayLimit
        let visibleClips = (displayLimit > 0) ? Array(clips.prefix(displayLimit)) : clips

        for (index, clip) in visibleClips.enumerated() {
            let previewText = clip.preview(limit: snippetLimit)
            let keyEq = index < 10 ? "\(index)" : ""
            let item = NSMenuItem(title: previewText, action: #selector(clipItemSelected(_:)), keyEquivalent: keyEq)
            if index < 10 {
                item.keyEquivalentModifierMask = .command
            }
            item.target = self
            item.representedObject = clip
            item.toolTip = "\(clip.appName ?? "App") • \(clip.formattedDate)\n\(clip.text)"
            if clip.isPinned {
                item.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
            }
            menu.addItem(item)
        }
    }

    private func buildKeywordGroupedMenuItems(into menu: NSMenu) {
        let monitor = ClipboardMonitorService.shared
        let clips = monitor.clips
        let prefs = AppPreferences.shared

        if clips.isEmpty {
            let emptyItem = NSMenuItem(title: "No clippings recorded yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        var keywordMap: [String: [ClipItem]] = [:]
        for clip in clips {
            let keys = clip.keywords.isEmpty ? ["General"] : clip.keywords
            for key in keys {
                keywordMap[key, default: []].append(clip)
            }
        }
        for key in keywordMap.keys {
            keywordMap[key]?.sort { $0.timestamp > $1.timestamp }
        }

        let sorted = sortKeywordGroups(keywordMap: keywordMap, mode: prefs.tagSortMode)
        let tagLimit = prefs.tagDisplayLimit
        let visibleKeywords = (tagLimit > 0) ? Array(sorted.prefix(tagLimit)) : sorted

        for (keyword, clipList) in visibleKeywords {
            let groupItem = buildKeywordGroupItem(
                keyword: keyword,
                clipList: clipList,
                mode: prefs.tagSortMode,
                snippetLimit: prefs.maxSnippetLength,
                clipLimit: prefs.chronoDisplayLimit > 0 ? prefs.chronoDisplayLimit : 25
            )
            menu.addItem(groupItem)
        }
    }

    private func sortKeywordGroups(
        keywordMap: [String: [ClipItem]],
        mode: AppPreferences.TagSortMode
    ) -> [(key: String, value: [ClipItem])] {
        switch mode {
        case .mostFrequent:
            return keywordMap.sorted {
                if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
                return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }
        case .hottest:
            return keywordMap.sorted {
                let timeFirst = $0.value.map(\.timestamp).max() ?? Date.distantPast
                let timeSecond = $1.value.map(\.timestamp).max() ?? Date.distantPast
                if timeFirst != timeSecond { return timeFirst > timeSecond }
                return $0.value.count > $1.value.count
            }
        case .all:
            return keywordMap.sorted {
                $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }
        }
    }

    private func buildKeywordGroupItem(
        keyword: String,
        clipList: [ClipItem],
        mode: AppPreferences.TagSortMode,
        snippetLimit: Int,
        clipLimit: Int
    ) -> NSMenuItem {
        let badgeIcon = mode == .hottest ? "🔥" : (mode == .mostFrequent ? "📊" : "🏷️")
        let groupItem = NSMenuItem(title: "\(badgeIcon) \(keyword) (\(clipList.count))", action: nil, keyEquivalent: "")
        let groupSubmenu = NSMenu(title: keyword)

        for (index, clip) in clipList.prefix(clipLimit).enumerated() {
            let previewText = clip.preview(limit: snippetLimit)
            let keyEq = index < 10 ? "\(index)" : ""
            let subItem = NSMenuItem(
                title: previewText,
                action: #selector(clipItemSelected(_:)),
                keyEquivalent: keyEq
            )
            if index < 10 {
                subItem.keyEquivalentModifierMask = .command
            }
            subItem.target = self
            subItem.representedObject = clip
            subItem.toolTip = "\(clip.appName ?? "App") • \(clip.formattedDate)\n\(clip.text)"
            if clip.isPinned {
                subItem.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
            }
            groupSubmenu.addItem(subItem)
        }
        groupItem.submenu = groupSubmenu
        return groupItem
    }

    private func buildActionMenuItems(into menu: NSMenu) {
        let clips = ClipboardMonitorService.shared.clips

        // 1. "All History" Submenu
        let allHistoryItem = NSMenuItem(title: "All History", action: nil, keyEquivalent: "")
        let allHistorySubmenu = NSMenu(title: "All History")

        let copyAllItem = NSMenuItem(title: "Copy All", action: #selector(copyAllHistorySelected), keyEquivalent: "")
        copyAllItem.target = self
        copyAllItem.isEnabled = !clips.isEmpty
        allHistorySubmenu.addItem(copyAllItem)

        let exportAllItem = NSMenuItem(
            title: "Export All…",
            action: #selector(exportAllHistorySelected),
            keyEquivalent: ""
        )
        exportAllItem.target = self
        exportAllItem.isEnabled = !clips.isEmpty
        allHistorySubmenu.addItem(exportAllItem)

        allHistorySubmenu.addItem(NSMenuItem.separator())

        let deleteAllItem = NSMenuItem(
            title: "Delete All…",
            action: #selector(deleteAllHistorySelected),
            keyEquivalent: ""
        )
        deleteAllItem.target = self
        deleteAllItem.isEnabled = !clips.isEmpty
        allHistorySubmenu.addItem(deleteAllItem)

        allHistoryItem.submenu = allHistorySubmenu
        menu.addItem(allHistoryItem)
        menu.addItem(NSMenuItem.separator())

        // 2. Open Cloud History Viewer
        let webItem = NSMenuItem(
            title: "Open Cloud History Viewer…",
            action: #selector(openWebViewerSelected),
            keyEquivalent: ""
        )
        webItem.target = self
        menu.addItem(webItem)

        // 3. Preferences…
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferencesAction), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = .command
        prefsItem.target = self
        menu.addItem(prefsItem)
        menu.addItem(NSMenuItem.separator())

        // 4. Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitAppSelected), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)
    }
}
