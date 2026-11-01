import SwiftUI
import AppKit

public struct SyncTabView: View {
    @ObservedObject var prefs = AppPreferences.shared
    @ObservedObject var syncService = NetworkSyncService.shared
    @ObservedObject var monitor = ClipboardMonitorService.shared

    @State private var isMerging = false
    @State private var isTesting = false
    @State private var statusFeedback: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Live Sync Health & Verification Card
            syncHealthCard

            // 2. Account & Shareword Section
            accountSection

            Divider()

            // 3. Multi-Mac Unification Actions
            unificationSection

            Divider()

            // 4. Server Endpoint & Presets
            serverSection

            Spacer()

            // 5. Persistent Bottom Status
            bottomStatusRow
        }
        .padding(16)
        .onAppear {
            syncService.testConnection { _, _ in }
        }
    }

    private var syncHealthCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(syncService.isServerReachable ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(syncService.isServerReachable ? "Connected & Synchronized" : "Local Hub Standby")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(syncService.isServerReachable ? .green : .orange)
                }
                Spacer()
                if let lat = syncService.latencyMs {
                    Text("\(lat) ms latency")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Active Hub:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(syncService.activeEndpointLabel)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }

                Divider().frame(height: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Last Synced:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(syncService.lastSyncTimeFormatted)
                        .font(.system(size: 11, weight: .medium))
                }

                Divider().frame(height: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Clips In Sync:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(monitor.clips.count) clippings")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        )
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account & Shareword")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 10) {
                Text("Email:")
                    .font(.system(size: 12))
                    .frame(width: 80, alignment: .trailing)
                TextField("name@example.com", text: $prefs.userEmail)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
            }

            HStack(spacing: 10) {
                Text("Shareword:")
                    .font(.system(size: 12))
                    .frame(width: 80, alignment: .trailing)

                TextField("77 amber tigers", text: $prefs.shareword)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 170)

                Button("Generate New") {
                    prefs.shareword = AppPreferences.generateRandomShareword()
                }
                .font(.system(size: 11))
            }

            Text("Colloquial code (e.g. 77 amber tigers). Singular/plural both match across Macs.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.leading, 92)
        }
    }

    private var unificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Multi-Mac Unification")
                .font(.system(size: 13, weight: .semibold))

            Toggle("Automatically merge clippings across Macs with this Email & Shareword", isOn: $prefs.autoMerge)
                .font(.system(size: 12))
                .toggleStyle(.checkbox)
                .padding(.leading, 8)

            HStack(spacing: 12) {
                Button(action: runMergeNow) {
                    if isMerging {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Merge with Cloud Now")
                    }
                }
                .disabled(isMerging)
                .padding(.leading, 8)

                Button("Open Cloud Viewer") {
                    AppDelegate.sharedInstance?.openWebViewerSelected()
                }

                Button("Open Local Viewer") {
                    AppDelegate.sharedInstance?.openLocalWebViewerSelected()
                }
            }
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Server:")
                    .font(.system(size: 12))
                    .frame(width: 80, alignment: .trailing)
                TextField("http://127.0.0.1:8008", text: $prefs.syncHost)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 210)

                Menu("Presets") {
                    Button("Local Hub (127.0.0.1:8008)") {
                        prefs.syncHost = "http://127.0.0.1:8008"
                        syncService.testConnection { _, _ in }
                    }
                    Button("Custom Cloud Server") {
                        if prefs.syncHost.contains("127.0.0.1") || prefs.syncHost.isEmpty {
                            prefs.syncHost = "https://sync.example.com"
                        }
                        syncService.testConnection { _, _ in }
                    }
                }
                .font(.system(size: 11))

                Button(isTesting ? "Testing…" : "Test Connection") {
                    testServerConnection()
                }
                .font(.system(size: 11))
                .disabled(isTesting)
            }
        }
    }

    private var bottomStatusRow: some View {
        HStack {
            Text("Linked: \(prefs.userEmail) • \(prefs.shareword)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            if let feedback = statusFeedback {
                Text(feedback)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func testServerConnection() {
        isTesting = true
        statusFeedback = "Testing connection to \(prefs.syncHost)…"
        syncService.testConnection { _, msg in
            isTesting = false
            statusFeedback = msg
        }
    }

    private func runMergeNow() {
        isMerging = true
        statusFeedback = "Merging with cloud…"
        syncService.performSync(clips: monitor.clips, isExplicitMerge: true) { _, msg in
            isMerging = false
            statusFeedback = msg
        }
    }
}
