import Foundation

enum RiskLevel: String, CaseIterable, Identifiable, Sendable {
    case safe
    case usuallySafe
    case review
    case protected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safe: "Safe"
        case .usuallySafe: "Usually Safe"
        case .review: "Review"
        case .protected: "Do Not Auto-Select"
        }
    }

    var shortExplanation: String {
        switch self {
        case .safe:
            "Rebuildable cache or temporary data."
        case .usuallySafe:
            "Usually removable, but the app or macOS may redownload or recreate it."
        case .review:
            "May include personal files, app state, browser data, or project work."
        case .protected:
            "Shown for visibility only. Review manually before deleting."
        }
    }

    var allowsDefaultSelection: Bool {
        switch self {
        case .safe, .usuallySafe: true
        case .review, .protected: false
        }
    }

    var canMoveToTrash: Bool {
        self != .protected
    }
}

enum FindingCategory: String, CaseIterable, Identifiable, Sendable {
    case appleSystem
    case developer
    case adobePhoto
    case browser
    case appData
    case cache
    case personal
    case media
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleSystem: "Apple System Bloat"
        case .developer: "Developer Storage"
        case .adobePhoto: "Adobe & Photo Caches"
        case .browser: "Browser Storage"
        case .appData: "App Support Data"
        case .cache: "Rebuildable Caches"
        case .personal: "Personal Files"
        case .media: "Media"
        case .other: "Other"
        }
    }
}

enum FindingFilter: String, CaseIterable, Identifiable {
    case all
    case safe
    case review
    case large
    case apple
    case developer
    case browser
    case personal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .safe: "Safe"
        case .review: "Review"
        case .large: "Large"
        case .apple: "Apple"
        case .developer: "Developer"
        case .browser: "Browser"
        case .personal: "Personal"
        }
    }
}

struct StorageFinding: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let sizeBytes: Int64
    let url: URL
    let category: FindingCategory
    let risk: RiskLevel
    let explanation: String
    let sideEffect: String
    let source: String

    var path: String { url.path }
}

struct CleanupDraft: Identifiable {
    let id = UUID()
    let findings: [StorageFinding]

    var totalBytes: Int64 {
        findings.reduce(0) { $0 + $1.sizeBytes }
    }

    var hasReviewItems: Bool {
        findings.contains { $0.risk == .review }
    }
}

struct CleanupResult: Identifiable {
    let id = UUID()
    let movedCount: Int
    let failed: [(StorageFinding, String)]
    let reclaimedBytes: Int64
}

extension Int64 {
    var storageString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: self)
    }
}
