import SwiftUI

public struct ClipRowView: View {
    public let clip: ClipItem
    public let index: Int?
    public let maxSnippetLength: Int
    public let isHovered: Bool
    public let onSelect: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void

    public init(
        clip: ClipItem,
        index: Int? = nil,
        maxSnippetLength: Int = 65,
        isHovered: Bool = false,
        onSelect: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.clip = clip
        self.index = index
        self.maxSnippetLength = maxSnippetLength
        self.isHovered = isHovered
        self.onSelect = onSelect
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Hotkey / Index pill
            if let idx = index, idx <= 9 {
                Text("\(idx)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isHovered ? .white : .secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(isHovered ? Color.blue : Color.gray.opacity(0.18))
                    )
            } else {
                Image(systemName: clip.isPinned ? "pin.fill" : "doc.on.clipboard")
                    .font(.system(size: 11))
                    .foregroundColor(clip.isPinned ? .orange : (isHovered ? .blue : .secondary))
                    .frame(width: 20, height: 20)
            }

            // Text Preview & Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(clip.preview(limit: maxSnippetLength))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let app = clip.appName, !app.isEmpty {
                        Text(app)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    Text(clip.timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("\(clip.charCount) chars")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            Spacer()

            // Hover Quick Actions
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onTogglePin) {
                        Image(systemName: clip.isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 11))
                            .foregroundColor(clip.isPinned ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(clip.isPinned ? "Unpin clip" : "Pin clip to top")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete clip")
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button(action: onSelect) {
                Label("Copy & Paste", systemImage: "doc.on.clipboard")
            }
            Button(action: {
                ClipboardMonitorService.shared.selectClip(clip, autoPaste: false)
            }) {
                Label("Copy to Clipboard Only", systemImage: "doc.on.doc")
            }
            Divider()
            Button(action: onTogglePin) {
                Label(clip.isPinned ? "Unpin Clip" : "Pin to Top", systemImage: clip.isPinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Clip", systemImage: "trash")
            }
        }
    }
}
