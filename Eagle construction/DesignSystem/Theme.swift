import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum Palette {
    static let primary = Color(hex: 0x01385F)
    static let primary700 = Color(hex: 0x012A48)
    static let primary50 = Color(hex: 0xEEF4F9)
    static let primary100 = Color(hex: 0xD8E5EF)
    static let navyButton = Color(hex: 0x1A4C74)
    static let navyAccent = Color(hex: 0x2A6496)
    static let onNavy = Color(hex: 0xC9D8E6)

    static let ink = Color(hex: 0x0B1B2B)
    static let text2 = Color(hex: 0x465567)
    static let text3 = Color(hex: 0x6B7787)
    static let muted = Color(hex: 0x9AA4B1)
    static let border = Color(hex: 0xE2E7ED)
    static let hairline = Color(hex: 0xEBEEF2)
    static let divider = Color(hex: 0xEEF1F4)
    static let background = Color(hex: 0xF3F5F8)
    static let star = Color(hex: 0xF2A900)
    static let starBackground = Color(hex: 0xFFF7E0)
}

enum Tone {
    case success, danger, warning, info, neutral, brand

    var foreground: Color {
        switch self {
        case .success: Color(hex: 0x0F7B4F)
        case .danger: Color(hex: 0xC8322B)
        case .warning: Color(hex: 0xA35A00)
        case .info: Color(hex: 0x1F5FBF)
        case .neutral: Palette.text2
        case .brand: Palette.primary
        }
    }

    var background: Color {
        switch self {
        case .success: Color(hex: 0xE7F6EE)
        case .danger: Color(hex: 0xFDECEB)
        case .warning: Color(hex: 0xFFF3DE)
        case .info: Color(hex: 0xE9F1FC)
        case .neutral: Palette.divider
        case .brand: Palette.primary50
        }
    }

    static func forStatus(_ status: String) -> Tone {
        switch status {
        case "Open", "Already Applied", "Completed", "Resolved": .success
        case "Closed", "Not Resolved", "Cancelled", "Dispute", "Cancellation Dispute": .danger
        case "In progress": .info
        case "Approval Pending", "Waiting Approval", "Cancellation Pending", "Pending": .warning
        default: .neutral
        }
    }
}

enum Radius {
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

extension View {
    /// Shorthand for the design's type scale.
    func type(_ size: CGFloat, _ weight: Font.Weight = .regular, _ color: Color = Palette.ink) -> some View {
        font(.system(size: size, weight: weight)).foregroundStyle(color)
    }

    /// Elevated white surface used by every card.
    func card(radius: CGFloat = Radius.lg, fill: Color = .white) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
            .shadow(color: Palette.ink.opacity(0.06), radius: 10, y: 4)
    }

    /// Light status bar text, for screens with a navy or photo header.
    func lightStatusBar() -> some View { statusBar(light: true) }

    /// Dark status bar text, for screens with a white header.
    func darkStatusBar() -> some View { statusBar(light: false) }

    func statusBar(light: Bool) -> some View { modifier(StatusBarModifier(light: light)) }
}

extension Text {
    /// Runs of differently styled text as one Text.
    static func joined(_ first: Text, _ second: Text) -> Text {
        Text("\(first)\(second)")
    }
}

/// Each screen tells the root controller which status bar text it needs when it appears.
enum StatusBar {
    static var isLight = false

    static func apply(light: Bool) {
        isLight = light
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }
}

private struct StatusBarModifier: ViewModifier {
    let light: Bool

    func body(content: Content) -> some View {
        content
            .onAppear { StatusBar.apply(light: light) }
            .onChange(of: light) { _, value in StatusBar.apply(light: value) }
    }
}
