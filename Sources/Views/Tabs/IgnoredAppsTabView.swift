import SwiftUI
import AppKit

public struct IgnoredAppsTabView: View {
    @ObservedObject var prefs = AppPreferences.shared
    @State private var selectedAppId: String?
    @State private var showingAddSheet = false
    @State private var customAppName = ""
    @State private var customBundleId = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Excluded Applications")
                        .font(.system(size: 14, weight: .bold))
                    Text("Clips copied while working inside these applications will be ignored to protect sensitive credentials and private data.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Ignored Apps List Table
            List(selection: $selectedAppId) {
                ForEach(prefs.ignoredApps) { app in
                    HStack(spacing: 12) {
                        Image(systemName: app.isEnabled ? "shield.lefthalf.filled" : "shield.slash")
                            .font(.system(size: 14))
                            .foregroundColor(app.isEnabled ? .blue : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.system(size: 13, weight: .medium))
                            Text(app.bundleId)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { app.isEnabled },
                            set: { newValue in
                                if let idx = prefs.ignoredApps.firstIndex(where: { $0.id == app.id }) {
                                    prefs.ignoredApps[idx].isEnabled = newValue
                                }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    .padding(.vertical, 3)
                    .tag(app.id)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(height: 230)
            .border(Color.gray.opacity(0.2), width: 1)

            // Action Buttons
            HStack(spacing: 10) {
                Button(action: addRunningApps) {
                    Label("Add Running App…", systemImage: "plus")
                }

                Button(action: addFromDisk) {
                    Label("Browse Applications…", systemImage: "folder")
                }

                Button(role: .destructive, action: removeSelected) {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selectedAppId == nil)

                Spacer()

                Button("Restore Security Defaults") {
                    restoreDefaults()
                }
                .font(.system(size: 11))
            }

            // Security note banner
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                Text("Password managers (1Password, Bitwarden, Apple Passwords, Keychain Access) are protected by default so your master passwords and tokens stay secure.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.green.opacity(0.08))
            .cornerRadius(8)

            Spacer()
        }
        .padding(20)
    }

    private func removeSelected() {
        guard let sel = selectedAppId else { return }
        prefs.ignoredApps.removeAll { $0.id == sel }
        selectedAppId = nil
    }

    private func addRunningApps() {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> IgnoredApp? in
                guard let name = app.localizedName, let bid = app.bundleIdentifier else { return nil }
                return IgnoredApp(name: name, bundleId: bid, isEnabled: true)
            }

        for app in running {
            if !prefs.ignoredApps.contains(where: { $0.bundleId.lowercased() == app.bundleId.lowercased() }) {
                prefs.ignoredApps.append(app)
                break
            }
        }
    }

    private func addFromDisk() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            let name = (bundle?.infoDictionary?["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent
            let bid = bundle?.bundleIdentifier ?? "com.unknown.\(name.lowercased())"

            if !prefs.ignoredApps.contains(where: { $0.bundleId == bid }) {
                prefs.ignoredApps.append(IgnoredApp(name: name, bundleId: bid, isEnabled: true))
            }
        }
    }

    private func restoreDefaults() {
        prefs.ignoredApps = [
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
