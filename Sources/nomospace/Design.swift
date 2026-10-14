import AppKit
import SwiftUI

/// NomoSpace's native adaptation of Supreme AI Ventures' "ink + mineral" design.
/// Colors originate from the public brand site and adapt to the macOS appearance.
enum AppTheme {
    private static func rgb(_ value: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 255) / 255,
            green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255,
            alpha: 1
        )
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return rgb(isDark ? dark : light)
        })
    }

    static let page = adaptive(light: 0xEDF0EE, dark: 0x0B1416)
    static let pageSecondary = adaptive(light: 0xE2E8E5, dark: 0x101C1E)
    static let panel = adaptive(light: 0xF9FBF9, dark: 0x142326)
    static let border = adaptive(light: 0xCCD6D3, dark: 0x2B4145)
    static let textPrimary = adaptive(light: 0x0C1518, dark: 0xE7EEEC)
    static let textMuted = adaptive(light: 0x56676B, dark: 0x94A8AA)
    static let accent = adaptive(light: 0x0B6B73, dark: 0x5CC4B8)
    static let accentSubtle = adaptive(light: 0xD8EEEA, dark: 0x173F40)
    static let ink = Color(red: 12 / 255, green: 21 / 255, blue: 24 / 255)
    static let inkSecondary = Color(red: 19 / 255, green: 34 / 255, blue: 31 / 255)
    static let mint = Color(red: 159 / 255, green: 224 / 255, blue: 214 / 255)
    static let onDark = Color(red: 233 / 255, green: 240 / 255, blue: 238 / 255)
    static let onDarkMuted = Color(red: 143 / 255, green: 165 / 255, blue: 167 / 255)
    static let darkLine = Color(red: 36 / 255, green: 54 / 255, blue: 58 / 255)
    static let slate = adaptive(light: 0x4A5F7A, dark: 0xA9B8CC)
    static let green = adaptive(light: 0x176A58, dark: 0x87D8C1)
    static let amber = adaptive(light: 0xA45D17, dark: 0xF0BF79)
    static let red = adaptive(light: 0xA43E43, dark: 0xF0A5A5)
    static let ctaText = adaptive(light: 0xFFFFFF, dark: 0x0C1518)

    static func eyebrow(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(textMuted)
    }
}

extension RiskLevel {
    var tint: Color {
        switch self {
        case .safe: AppTheme.green
        case .usuallySafe: AppTheme.slate
        case .review: AppTheme.amber
        case .protected: AppTheme.red
        }
    }

    var symbolName: String {
        switch self {
        case .safe: "checkmark.shield"
        case .usuallySafe: "arrow.triangle.2.circlepath"
        case .review: "exclamationmark.triangle"
        case .protected: "lock.shield"
        }
    }
}

extension FindingCategory {
    var symbolName: String {
        switch self {
        case .appleSystem: "apple.logo"
        case .developer: "hammer"
        case .adobePhoto: "camera.aperture"
        case .browser: "globe"
        case .appData: "app.dashed"
        case .cache: "externaldrive.badge.timemachine"
        case .personal: "folder"
        case .media: "photo.on.rectangle"
        case .other: "archivebox"
        }
    }
}

struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(AppTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(AppTheme.border.opacity(0.8), lineWidth: 1)
            )
    }
}

extension View {
    func panel() -> some View { modifier(PanelBackground()) }
}

struct BrandPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.ctaText)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Capsule().fill(AppTheme.accent))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .contentShape(Capsule())
    }
}

struct BrandSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().strokeBorder(AppTheme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// Abstract N mark. Designed for the app; does not reuse the corporate logo.
struct NomospaceMark: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.mint.opacity(0.12))
            Path { path in
                path.move(to: CGPoint(x: size * 0.18, y: size * 0.78))
                path.addLine(to: CGPoint(x: size * 0.18, y: size * 0.22))
                path.addLine(to: CGPoint(x: size * 0.78, y: size * 0.78))
                path.addLine(to: CGPoint(x: size * 0.78, y: size * 0.22))
            }
            .stroke(AppTheme.mint, style: StrokeStyle(lineWidth: 2.6, lineCap: .square, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct EditorialPageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppTheme.eyebrow(eyebrow)
            Text(title)
                .font(.system(size: 34, weight: .medium))
                .tracking(-1.25)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
