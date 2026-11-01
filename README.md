# 📎 BlueClip — Next-Generation macOS Clipboard Manager with Private Cloud Sync

**BlueClip** is a native macOS menu bar application designed and built from the ground up as a modern successor to FIPLAB's **CopyClip**. It retains all the beloved lightweight clipboard caching features of CopyClip, modernizes the interface with a custom **vibrant Blue Icon** and refined SwiftUI design, and introduces a powerful **Private Cloud Network Sync** engine that syncs your copy-paste history to your personal server infrastructure with colloquial shareword authentication.

---

## 🔍 Feature Comparison: CopyClip vs. BlueClip

| Feature Category | Original CopyClip (v1.9.87) | New BlueClip (v2.0) |
| :--- | :--- | :--- |
| **Menu Bar Icon** | Black squircle / monochrome paperclip | **Vibrant Royal Blue Icon** (with optional template mode) |
| **History Navigation** | Numbered hotkeys 1–9, plain text list | **Numbered 1–9 hotkeys**, app source badges, timestamps, search filter |
| **Auto-Paste Simulation** | ⌘V simulation into active frontmost app | **High-precision CGEvent ⌘V injection** with focus restoration |
| **Audio Feedback** | System click sound | **Native macOS audio feedback** (`Tink` on copy, `Pop` on select) |
| **Ignored Apps (Blacklist)** | Exclude selected apps from recording | **Preconfigured security blacklist** (1Password, Bitwarden, Keychain, Passwords) + custom app picker |
| **Clips Management** | Basic list view | **Split-view Inspector**: raw monospace viewer, word/character/line counts, export to JSON/CSV/TXT |
| **Pinning Support** | Not supported | **Pin essential clips** to preserve them from auto-deletion |
| **Cloud Synchronization** | ❌ None (Local only) | 🌐 **Private Network Sync** (custom cloud server or local hub) |
| **Cross-Device Web Viewer** | ❌ None | 📱 **Responsive Web History Dashboard** (`web_viewer.html`) with tag grouping |

---

## 🏛️ Application Architecture

```text
BlueClip/
├── Package.swift                    # Swift Package Manager manifest
├── run.sh                           # Build & packaging script (.app bundle)
├── Resources/
│   ├── AppIcon.icns                 # High-resolution macOS application icon bundle
│   ├── AppIcon.png                  # 1024x1024 master icon
│   ├── MenuBarIconBlue.png          # Signature vibrant blue menu bar asset
│   └── MenuBarIcon.png              # Adaptive monochrome menu bar asset
├── Sources/
│   ├── BlueClipApp.swift            # StatusItem, popover manager & lifecycle
│   ├── Models/
│   │   ├── ClipItem.swift           # Codable clip model with timeAgo & preview
│   │   ├── AppPreferences.swift     # UserDefaults persistent settings & blacklist
│   │   └── SyncStatus.swift         # Network sync payload & status models
│   ├── Services/
│   │   ├── ClipboardMonitorService.swift # NSPasteboard polling & deduplication
│   │   ├── StorageService.swift     # Local JSON persistence & export engines
│   │   ├── NetworkSyncService.swift # REST sync engine with SHA-256 token hashing
│   │   └── AutoPasteService.swift   # CGEvent virtual keycode injection
│   └── Views/
│       ├── MenuBarPopupView.swift   # Dropdown popover with search & quick copy
│       ├── PreferencesView.swift    # 5-tab macOS settings window
│       └── Tabs/
│           ├── GeneralTabView.swift          # Max clips, snippet limits, sounds
│           ├── IgnoredAppsTabView.swift      # Blacklist management
│           ├── ClipsManagementTabView.swift  # Master-detail clip inspector
│           ├── SyncTabView.swift             # Private network sync configuration
│           └── AboutTabView.swift            # Branded About view with live stats
└── server/
    ├── clipboard_server.py          # Zero-dependency Python standard library server
    ├── web_viewer.html              # Responsive web viewer with tag grouping
    └── clipboard_history.sample.json # Sample schema payload
```

---

## 🚀 Quick Start

### 1. Launching BlueClip
Execute the launcher script:
```bash
./run.sh
```
BlueClip will compile, create `build/BlueClip.app`, and place the **Blue Paperclip** icon in your macOS menu bar.

### 2. Copy & Paste Operations
- Copy text anywhere on your Mac (`⌘C`). BlueClip automatically records the text, source app, and timestamp.
- Click the **Blue Paperclip** icon in the menu bar.
- Press **⌘0–⌘9** or click any clip to automatically copy it and paste (`⌘V`) it into your current document.

### 3. Preferences & Blacklisting
- Open **Preferences…** (`⌘,`).
- Switch to **Ignored Apps** to prevent sensitive credentials from 1Password or Keychain from being saved.
- Switch to **Sync** to view your server link status or pair other Macs using your Email and Colloquial Shareword.

---

## 🌐 Private Network Synchronization

BlueClip writes its synced state to:
1. **Configured Cloud Endpoint**: `POST <your-server-url>/api/clipboard-sync`
2. **Local Zero-Dependency Hub**: `http://127.0.0.1:8008` (automatically started via `run.sh`)
3. **Web Viewer Dashboard**: `server/web_viewer.html`

To run the web viewer on a remote server or locally, refer to [`server/README_SERVER.md`](server/README_SERVER.md).
