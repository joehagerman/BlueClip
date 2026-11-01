import SwiftUI
import AppKit

public struct BlueClipLogoView: View {
    @ObservedObject var prefs = AppPreferences.shared
    public var size: CGFloat = 80
    @State private var bounce = false

    public init(size: CGFloat = 80) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Squircle Background
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.55, blue: 1.0),
                            Color(red: 0.02, green: 0.35, blue: 0.88),
                            Color(red: 0.01, green: 0.20, blue: 0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.blue.opacity(0.35), radius: size * 0.12, x: 0, y: size * 0.06)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: size * 0.018)
                )

            // Emoji Display (Blue Pushpin by default, or active easter egg emoji)
            Text(prefs.currentEmoji)
                .font(.system(size: size * 0.52))
                .scaleEffect(bounce ? 1.25 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: bounce)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Easter egg: Command-Click cycles the emoji!
            if NSEvent.modifierFlags.contains(.command) {
                bounce = true
                prefs.cycleEasterEggEmoji()
                NSSound(named: "Hero")?.play()
                AppDelegate.sharedInstance?.updateStatusBarIcon()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    bounce = false
                }
            }
        }
        .help("Tip: ⌘-Click icon to cycle Easter Egg emojis!")
    }
}
