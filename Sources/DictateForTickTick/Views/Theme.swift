import AppKit
import SwiftUI

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// TickTick's visual language: flat light surfaces, blue accent, moderate radii, dense list.
enum Theme {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }

    static let accent = Color(nsColor: NSColor(hex: 0x4772FA))
    static let background = dynamic(0xF7F8FA, 0x1B1B1D)
    static let card = dynamic(0xFFFFFF, 0x252528)
    static let text = dynamic(0x191A1C, 0xECECEF)
    static let secondary = dynamic(0x8A8F99, 0x9B9BA1)
    static let separator = dynamic(0xE8EAEE, 0x34343A)
    static let chip = dynamic(0xF1F3F6, 0x2F2F34)
    static let input = dynamic(0xFFFFFF, 0x1E1E21)
    static let inputBorder = dynamic(0xCDD2DA, 0x48484F)
    static let error = Color(nsColor: NSColor(hex: 0xD52B24))
    static let uncertainFill = dynamic(0xFFF3C4, 0x4A3F18)
    static let success = Color(nsColor: NSColor(hex: 0x3BB273))

    static func priority(_ p: Priority) -> Color {
        switch p {
        case .p1: return Color(nsColor: NSColor(hex: 0xD52B24))
        case .p2: return Color(nsColor: NSColor(hex: 0xFAA80C))
        case .p3: return Color(nsColor: NSColor(hex: 0x4772FA))
        case .p4: return Color(nsColor: NSColor(hex: 0xA8A8A8))
        }
    }
}

struct IconButton: View {
    let systemName: String
    var size: CGFloat = 20
    var help: String?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.7, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .frame(width: size + 10, height: size + 10)
                .background(Circle().fill(hovering ? Theme.chip : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help ?? "")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.white : Theme.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 10).fill(isEnabled ? Theme.accent : Theme.chip))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(configuration.isPressed ? 0.16 : 0.1)))
            .contentShape(Rectangle())
    }
}

struct SmallButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(tint.opacity(configuration.isPressed ? 0.18 : 0.1)))
            .contentShape(Rectangle())
    }
}

/// Header shared by all screens: title in the middle, gear on the right.
struct HeaderBar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    var title: String?
    var showGear = true

    var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            HStack {
                // Close / minimize are the window's own buttons in the top-left corner.
                Spacer()
                if showGear {
                    IconButton(systemName: "gearshape", help: settings.t(.settings)) {
                        withAnimation(.easeOut(duration: 0.2)) { app.showSettings = true }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
    }
}

@MainActor
enum DueFormatter {
    static func string(_ date: Date, allDay: Bool, settings: SettingsStore) -> String {
        let cal = Calendar.current
        let locale = settings.language.locale
        var day: String
        if cal.isDateInToday(date) {
            day = settings.t(.today)
        } else if cal.isDateInTomorrow(date) {
            day = settings.t(.tomorrow)
        } else {
            let f = DateFormatter()
            f.locale = locale
            let sameYear = cal.component(.year, from: date) == cal.component(.year, from: Date())
            f.setLocalizedDateFormatFromTemplate(sameYear ? "EEEdMMM" : "EEEdMMMyyyy")
            day = f.string(from: date)
        }
        if allDay { return day }
        let t = DateFormatter()
        t.locale = locale
        t.setLocalizedDateFormatFromTemplate("jmm")
        return "\(day), \(t.string(from: date))"
    }
}
