import CryptoKit
import Foundation

struct LockedFeature: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String

    static let fullAccess = LockedFeature(
        id: "full-access",
        title: "Unlock full access",
        message: "Evaluation mode can scan this Mac and show findings. Enter an access code to enable Trash-first cleanup, PDF reports, and cleanup history."
    )

    static let cleanup = LockedFeature(
        id: "cleanup",
        title: "Unlock cleanup",
        message: "Evaluation mode shows what nomospace found. Enter an access code to move selected findings to Trash."
    )

    static let pdf = LockedFeature(
        id: "pdf",
        title: "Unlock PDF reports",
        message: "Evaluation mode shows audit results in the app. Enter an access code to save local PDF reports."
    )
}

final class LicenseStore {
    private enum Keys {
        static let fullAccess = "license.fullAccess"
        static let activatedAt = "license.activatedAt"
    }

    private static let acceptedCodeHashes: Set<String> = [
        "cab4d505fc37acb76f750aaf3252bb7f45a55fa7e2da7890d0fbfdc1cd0656d1"
    ]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isFullAccessEnabled: Bool {
        defaults.bool(forKey: Keys.fullAccess)
    }

    var activatedAt: Date? {
        defaults.object(forKey: Keys.activatedAt) as? Date
    }

    @discardableResult
    func activate(code: String) -> Bool {
        let normalized = Self.normalized(code)
        guard !normalized.isEmpty else { return false }

        guard Self.acceptedCodeHashes.contains(Self.sha256Hex(normalized)) else {
            return false
        }

        defaults.set(true, forKey: Keys.fullAccess)
        defaults.set(Date(), forKey: Keys.activatedAt)
        return true
    }

    private static func normalized(_ code: String) -> String {
        code
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
