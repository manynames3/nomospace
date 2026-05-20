import AppKit
import Foundation

@MainActor
final class AuditViewModel: ObservableObject {
    @Published var findings: [StorageFinding] = []
    @Published var selectedIDs: Set<StorageFinding.ID> = []
    @Published var searchText = ""
    @Published var activeFilter: FindingFilter = .all
    @Published var isScanning = false
    @Published var cleanupDraft: CleanupDraft?
    @Published var cleanupResult: CleanupResult?
    @Published var lastScanDate: Date?

    private let scanner = StorageScanner()

    var filteredFindings: [StorageFinding] {
        findings.filter { finding in
            matchesSearch(finding) && matchesFilter(finding)
        }
    }

    var groupedFindings: [(FindingCategory, [StorageFinding])] {
        let grouped = Dictionary(grouping: filteredFindings, by: \.category)
        return FindingCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items.sorted { $0.sizeBytes > $1.sizeBytes })
        }
    }

    var totalReclaimableBytes: Int64 {
        findings
            .filter { $0.risk != .protected }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var safeBytes: Int64 {
        findings
            .filter { $0.risk == .safe || $0.risk == .usuallySafe }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var reviewBytes: Int64 {
        findings
            .filter { $0.risk == .review }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedFindings: [StorageFinding] {
        findings.filter { selectedIDs.contains($0.id) }
    }

    var selectedBytes: Int64 {
        selectedFindings.reduce(0) { $0 + $1.sizeBytes }
    }

    func runAudit() {
        guard !isScanning else { return }

        isScanning = true
        selectedIDs.removeAll()

        Task {
            let scanned = await scanner.scan()
            findings = scanned
            lastScanDate = Date()
            isScanning = false
        }
    }

    func toggle(_ finding: StorageFinding) {
        guard finding.risk.canMoveToTrash else { return }
        if selectedIDs.contains(finding.id) {
            selectedIDs.remove(finding.id)
        } else {
            selectedIDs.insert(finding.id)
        }
    }

    func selectSafeFindings() {
        selectedIDs = Set(
            findings
                .filter { $0.risk.allowsDefaultSelection && $0.risk.canMoveToTrash }
                .map(\.id)
        )
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func prepareCleanup() {
        let selected = selectedFindings.filter(\.risk.canMoveToTrash)
        guard !selected.isEmpty else { return }
        cleanupDraft = CleanupDraft(findings: selected)
    }

    func moveDraftToTrash() {
        guard let draft = cleanupDraft else { return }
        cleanupDraft = nil

        Task {
            let result = await TrashMover.moveToTrash(draft.findings)
            cleanupResult = result

            let movedIDs = Set(draft.findings.map(\.id)).subtracting(result.failed.map { $0.0.id })
            findings.removeAll { movedIDs.contains($0.id) }
            selectedIDs.subtract(movedIDs)
        }
    }

    func revealInFinder(_ finding: StorageFinding) {
        NSWorkspace.shared.activateFileViewerSelecting([finding.url])
    }

    private func matchesSearch(_ finding: StorageFinding) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        return finding.title.localizedCaseInsensitiveContains(query)
            || finding.path.localizedCaseInsensitiveContains(query)
            || finding.source.localizedCaseInsensitiveContains(query)
            || finding.explanation.localizedCaseInsensitiveContains(query)
    }

    private func matchesFilter(_ finding: StorageFinding) -> Bool {
        switch activeFilter {
        case .all:
            true
        case .safe:
            finding.risk == .safe || finding.risk == .usuallySafe
        case .review:
            finding.risk == .review || finding.risk == .protected
        case .large:
            finding.sizeBytes >= 5 * 1_024 * 1_024 * 1_024
        case .apple:
            finding.category == .appleSystem
        case .developer:
            finding.category == .developer
        case .browser:
            finding.category == .browser
        case .personal:
            finding.category == .personal || finding.category == .media
        }
    }
}

private enum TrashMover {
    static func moveToTrash(_ findings: [StorageFinding]) async -> CleanupResult {
        await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            var failed: [(StorageFinding, String)] = []
            var movedCount = 0
            var reclaimed: Int64 = 0

            for finding in findings {
                do {
                    var resultingURL: NSURL?
                    try fileManager.trashItem(
                        at: finding.url,
                        resultingItemURL: &resultingURL
                    )
                    movedCount += 1
                    reclaimed += finding.sizeBytes
                } catch {
                    failed.append((finding, error.localizedDescription))
                }
            }

            return CleanupResult(
                movedCount: movedCount,
                failed: failed,
                reclaimedBytes: reclaimed
            )
        }.value
    }
}
