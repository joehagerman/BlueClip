import SwiftUI

public struct PreferencesView: View {
    public enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case ignored = "Ignored"
        case management = "Management"
        case sync = "Sync"
        case about = "About"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .general: return "gearshape"
            case .ignored: return "eye.slash"
            case .management: return "clipboard"
            case .sync: return "arrow.triangle.2.circlepath"
            case .about: return "info.circle"
            }
        }
    }

    @State public var selectedTab: Tab = .general

    public init(selectedTab: Tab = .general) {
        self._selectedTab = State(initialValue: selectedTab)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // macOS Preferences Toolbar (General, Ignored, Management, Sync, About)
            HStack(spacing: 14) {
                ForEach(Tab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 22))
                                .frame(height: 24)
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .frame(width: 84, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.gray.opacity(0.12) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTab == tab ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Tab Contents
            Group {
                switch selectedTab {
                case .general:
                    GeneralTabView()
                case .ignored:
                    IgnoredAppsTabView()
                case .management:
                    ClipsManagementTabView()
                case .sync:
                    SyncTabView()
                case .about:
                    AboutTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 580, height: 430)
    }
}
