import Foundation
import AppKit
import SQLite3

public class CopyClipImporterService {
    public static let shared = CopyClipImporterService()

    public static let defaultContainerPath = ("~/Library/Containers/com.fiplab.clipboard" as NSString).expandingTildeInPath
    public static let defaultSQLitePath = ("~/Library/Containers/com.fiplab.clipboard/Data/Library/Application Support/CopyClip/copyclip.sqlite" as NSString).expandingTildeInPath

    public enum ImportError: LocalizedError {
        case fileNotFound
        case accessDenied
        case sqliteOpenFailed(String)
        case noClippingsFound

        public var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Could not locate copyclip.sqlite inside ~/Library/Containers/com.fiplab.clipboard"
            case .accessDenied:
                return "macOS restricted access to CopyClip sandbox. Please grant access using the folder picker."
            case .sqliteOpenFailed(let msg):
                return "Failed to read database: \(msg)"
            case .noClippingsFound:
                return "No clippings were found inside the CopyClip database."
            }
        }
    }

    public func importDirectlyOrPrompt(completion: @escaping (Result<Int, Error>) -> Void) {
        // Attempt direct access first
        if let count = tryDirectImport() {
            completion(.success(count))
            return
        }

        // If direct access restricted by TCC, prompt user via NSOpenPanel
        DispatchQueue.main.async {
            self.promptUserForAccess(completion: completion)
        }
    }

    private func tryDirectImport() -> Int? {
        let path = Self.defaultSQLitePath
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        do {
            let clips = try extractClipsFromSQLite(at: URL(fileURLWithPath: path))
            if !clips.isEmpty {
                applyImportedClips(clips)
                return clips.count
            }
        } catch {
            // Permission denied or unreadable
            return nil
        }
        return nil
    }

    public func promptUserForAccess(completion: @escaping (Result<Int, Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Grant Access to CopyClip History"
        panel.message = "Please select your CopyClip folder or copyclip.sqlite file in ~/Library/Containers/com.fiplab.clipboard to import your history."
        panel.prompt = "Import History"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        let appSupportDir = URL(fileURLWithPath: Self.defaultSQLitePath).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: appSupportDir.path) {
            panel.directoryURL = appSupportDir
        } else {
            panel.directoryURL = URL(fileURLWithPath: Self.defaultContainerPath)
        }

        NSApp.activate(ignoringOtherApps: true)

        if panel.runModal() == .OK, let selectedURL = panel.url {
            do {
                let sqliteURL = try locateSQLiteFile(from: selectedURL)
                let clips = try extractClipsFromSQLite(at: sqliteURL)
                if clips.isEmpty {
                    completion(.failure(ImportError.noClippingsFound))
                } else {
                    applyImportedClips(clips)
                    completion(.success(clips.count))
                }
            } catch {
                completion(.failure(error))
            }
        } else {
            completion(.failure(ImportError.accessDenied))
        }
    }

    private func locateSQLiteFile(from url: URL) throws -> URL {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
            return url
        }

        // Search inside directory for copyclip.sqlite or *.sqlite
        let candidates = [
            url.appendingPathComponent("copyclip.sqlite"),
            url.appendingPathComponent("Data/Library/Application Support/CopyClip/copyclip.sqlite"),
            url.appendingPathComponent("Library/Application Support/CopyClip/copyclip.sqlite"),
            url.appendingPathComponent("CoreDataStore.sqlite")
        ]

        for cand in candidates {
            if FileManager.default.fileExists(atPath: cand.path) {
                return cand
            }
        }

        // Fallback shallow enumerator
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent.lowercased().contains("copyclip") && fileURL.pathExtension == "sqlite" {
                    return fileURL
                }
            }
        }

        throw ImportError.fileNotFound
    }

    public func extractClipsFromSQLite(at fileURL: URL) throws -> [ClipItem] {
        var db: OpaquePointer?
        if sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw ImportError.sqliteOpenFailed(errmsg)
        }
        defer { sqlite3_close(db) }

        // CoreData reference date: 2001-01-01 00:00:00 UTC
        let coreDataEpoch = Date(timeIntervalSinceReferenceDate: 0)
        var results: [ClipItem] = []

        // Query ZCLIPPING table created by CoreData
        let query = "SELECT ZCONTENTS, ZDATERECORDED FROM ZCLIPPING ORDER BY Z_PK DESC;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cStr = sqlite3_column_text(stmt, 0) {
                    let text = String(cString: cStr)
                    var date = Date()
                    if sqlite3_column_type(stmt, 1) != SQLITE_NULL {
                        let seconds = sqlite3_column_double(stmt, 1)
                        date = coreDataEpoch.addingTimeInterval(seconds)
                    }

                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let clip = ClipItem(
                            text: text,
                            timestamp: date,
                            appBundleId: "com.fiplab.clipboard",
                            appName: "CopyClip",
                            isPinned: false
                        )
                        results.append(clip)
                    }
                }
            }
            sqlite3_finalize(stmt)
        } else {
            // Fallback: discover table name
            let tableQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%CLIP%';"
            var tableStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, tableQuery, -1, &tableStmt, nil) == SQLITE_OK {
                while sqlite3_step(tableStmt) == SQLITE_ROW {
                    if let tName = sqlite3_column_text(tableStmt, 0) {
                        print("Discovered table in CopyClip: \(String(cString: tName))")
                    }
                }
                sqlite3_finalize(tableStmt)
            }
        }

        return results
    }

    private func applyImportedClips(_ imported: [ClipItem]) {
        let monitor = ClipboardMonitorService.shared

        for clip in imported {
            if !monitor.clips.contains(where: { $0.text == clip.text }) {
                monitor.clips.append(clip)
            }
        }

        // Sort newest first
        monitor.clips.sort { (firstClip, secondClip) in
            if firstClip.isPinned != secondClip.isPinned {
                return firstClip.isPinned && !secondClip.isPinned
            }
            return firstClip.timestamp > secondClip.timestamp
        }

        monitor.enforceMaxClips()
        StorageService.shared.saveClips(monitor.clips)

        if AppPreferences.shared.syncEnabled {
            NetworkSyncService.shared.performSync(clips: monitor.clips)
        }
    }
}
