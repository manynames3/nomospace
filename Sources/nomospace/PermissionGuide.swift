import AppKit
import Foundation

enum PermissionGuide {
    static let fullDiskAccessURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )

    static func openFullDiskAccessSettings() {
        guard let url = fullDiskAccessURL else { return }
        NSWorkspace.shared.open(url)
    }
}
