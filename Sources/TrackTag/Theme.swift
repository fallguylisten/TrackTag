import SwiftUI

/// Colours and small shared pieces from the mockups.
enum Theme {
    static let window = Color(hex: 0x121316)
    static let header = Color(hex: 0x1A1B1F)
    static let panel = Color(hex: 0x141518)
    static let card = Color(hex: 0x17181B)
    static let field = Color(hex: 0x1C1D21)
    static let border = Color(hex: 0x2C2E33)
    static let borderStrong = Color(hex: 0x34363C)
    static let text = Color(hex: 0xECECEE)
    static let text2 = Color(hex: 0xC9CBD0)
    static let muted = Color(hex: 0xA3A6AD)

    // Workflow colours: orange = Library / general, teal = tagging, red = review.
    static let orange = Color(hex: 0xF5A524), orangeText = Color(hex: 0xF5C46B), orangeBg = Color(hex: 0x2A2213)
    static let teal = Color(hex: 0x4FC3C8), tealText = Color(hex: 0x7FD9DC), tealBg = Color(hex: 0x10292B)
    static let red = Color(hex: 0xF0555A), redText = Color(hex: 0xFF9497), redBg = Color(hex: 0x2E1517)
    static let grey = Color(hex: 0xC9CBD0)

    static func energyColor(_ e: Int) -> Color {
        switch e { case 1...3: return Color(hex: 0x2BD46A); case 4: return Color(hex: 0xFF9F1A); case 5: return Color(hex: 0xFF3B3B); default: return Color(hex: 0x5A5D63) }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Small keycap shown after a button label or in the shortcut bar.
struct Keycap: View {
    let key: String
    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.7), lineWidth: 1))
            .opacity(0.8)
    }
}

/// The strip of shortcut hints above the player, same on every tab.
struct ShortcutBar: View {
    let items: [(String, String)]
    var body: some View {
        HStack(spacing: 20) {
            ForEach(0..<items.count, id: \.self) { i in
                HStack(spacing: 6) {
                    Text(items[i].0).font(.system(size: 11)).foregroundStyle(Theme.text)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x26282D)))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.borderStrong))
                    Text(items[i].1).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 9)
        .background(Theme.header)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

/// A filter chip (All / Needs review / …).
struct FilterChip: View {
    let label: String
    let count: Int
    let selected: Bool
    var accent: Color = Theme.orange
    var accentText: Color = Theme.orangeText
    var accentBg: Color = Theme.orangeBg
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) { Text(label); Text(count.formatted()).monospacedDigit().foregroundStyle(selected ? accentText : Theme.muted) }
                .fixedSize()
                .font(.system(size: 13))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(selected ? accentText : Theme.text2)
                .background(RoundedRectangle(cornerRadius: 8).fill(selected ? accentBg : Theme.field))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? accent : Theme.borderStrong))
        }
        .buttonStyle(.plain)
    }
}
