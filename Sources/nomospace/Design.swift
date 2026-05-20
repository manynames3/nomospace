import SwiftUI

enum AppTheme {
    static let page = Color(nsColor: .windowBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.45)
    static let textMuted = Color.secondary
    static let accent = Color(red: 0.10, green: 0.35, blue: 0.95)
    static let green = Color(red: 0.08, green: 0.52, blue: 0.32)
    static let amber = Color(red: 0.74, green: 0.43, blue: 0.08)
    static let red = Color(red: 0.72, green: 0.16, blue: 0.16)
}

extension RiskLevel {
    var tint: Color {
        switch self {
        case .safe: AppTheme.green
        case .usuallySafe: AppTheme.accent
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func panel() -> some View {
        modifier(PanelBackground())
    }
}
