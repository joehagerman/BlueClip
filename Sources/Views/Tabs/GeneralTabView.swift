import SwiftUI

public struct GeneralTabView: View {
    @ObservedObject var prefs = AppPreferences.shared
    @ObservedObject var monitor = ClipboardMonitorService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)

            // Sliders Section
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text("Remember up to:")
                        .font(.system(size: 13))
                        .frame(width: 140, alignment: .trailing)

                    Slider(value: Binding(
                        get: { Double(prefs.maxClips) },
                        set: { prefs.maxClips = Int($0); monitor.enforceMaxClips() }
                    ), in: 10...300, step: 10)
                    .frame(width: 200)

                    Text("\(prefs.maxClips) clips")
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 80, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Text("Display preview limit:")
                        .font(.system(size: 13))
                        .frame(width: 140, alignment: .trailing)

                    Slider(value: Binding(
                        get: { Double(prefs.maxSnippetLength) },
                        set: { prefs.maxSnippetLength = Int($0) }
                    ), in: 30...150, step: 5)
                    .frame(width: 200)

                    Text("\(prefs.maxSnippetLength) chars")
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 80, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Text("Menu Sort Order:")
                        .font(.system(size: 13))
                        .frame(width: 140, alignment: .trailing)

                    Picker("", selection: $prefs.sortMode) {
                        Text("Chronological").tag(AppPreferences.SortMode.chrono)
                        Text("Keywords (AFM)").tag(AppPreferences.SortMode.keyword)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                if prefs.sortMode == .chrono {
                    HStack(spacing: 12) {
                        Text("Recent clips shown:")
                            .font(.system(size: 13))
                            .frame(width: 140, alignment: .trailing)

                        Picker("", selection: $prefs.chronoDisplayLimit) {
                            Text("5 clips").tag(5)
                            Text("10 clips").tag(10)
                            Text("15 clips").tag(15)
                            Text("25 clips").tag(25)
                            Text("50 clips").tag(50)
                            Text("All clips").tag(0)
                        }
                        .frame(width: 200)
                    }
                } else {
                    HStack(spacing: 12) {
                        Text("Tag ordering:")
                            .font(.system(size: 13))
                            .frame(width: 140, alignment: .trailing)

                        Picker("", selection: $prefs.tagSortMode) {
                            ForEach(AppPreferences.TagSortMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .frame(width: 200)
                    }

                    HStack(spacing: 12) {
                        Text("Show tags:")
                            .font(.system(size: 13))
                            .frame(width: 140, alignment: .trailing)

                        Picker("", selection: $prefs.tagDisplayLimit) {
                            Text("Top 5").tag(5)
                            Text("Top 10").tag(10)
                            Text("Top 15").tag(15)
                            Text("Top 25").tag(25)
                            Text("All Tags").tag(0)
                        }
                        .frame(width: 200)
                    }
                }
            }

            Divider()
                .padding(.horizontal, 40)

            // Checkboxes Section
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Automatically paste selected clip", isOn: $prefs.autoPaste)
                    .toggleStyle(.checkbox)

                Toggle("Play sound on copy", isOn: $prefs.playSound)
                    .toggleStyle(.checkbox)

                Toggle("Vibrant blue menu bar icon", isOn: $prefs.blueMenuBarIcon)
                    .toggleStyle(.checkbox)

                Toggle("Start BlueClip at system login", isOn: $prefs.launchAtLogin)
                    .toggleStyle(.checkbox)
            }
            .frame(width: 320, alignment: .leading)

            Spacer()
        }
        .padding(20)
    }
}
