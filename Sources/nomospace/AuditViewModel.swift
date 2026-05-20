import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AuditViewModel: ObservableObject {
    @Published var findings: [StorageFinding] = []
    @Published var selectedIDs: Set<StorageFinding.ID> = []
    @Published var searchText = ""
    @Published var activeFilter: FindingFilter = .all
    @Published var isScanning = false
    @Published var scanProgress = ScanProgress.idle
    @Published var scanIssues: [ScanIssue] = []
    @Published var cleanupDraft: CleanupDraft?
    @Published var cleanupResult: CleanupResult?
    @Published var reportExportResult: ReportExportResult?
    @Published var lastScanDate: Date?
    @Published var didCancelScan = false

    private let scanner: StorageScanner
    private let cancellation = ScanCancellation()
    let historyStore: HistoryStore

    init(
        scanner: StorageScanner = StorageScanner(),
        historyStore: HistoryStore = HistoryStore()
    ) {
        self.scanner = scanner
        self.historyStore = historyStore
    }

    var ruleCount: Int {
        scanner.rules.count
    }

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
        didCancelScan = false
        scanIssues = []
        scanProgress = ScanProgress(
            phase: "Starting audit",
            currentPath: "",
            scannedItems: 0,
            foundItems: 0
        )
        cancellation.reset()
        selectedIDs.removeAll()

        Task {
            let report = await scanner.scan(
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.scanProgress = progress
                    }
                },
                shouldCancel: { [cancellation] in
                    cancellation.isCancelled
                }
            )
            findings = report.findings
            var issues = report.issues
            if scanner.rules.isEmpty {
                issues.insert(
                    ScanIssue(
                        path: "Bundled rule library",
                        message: "nomospace could not load its cleanup rules. Reinstall the app or use a packaged build."
                    ),
                    at: 0
                )
            }
            scanIssues = issues
            lastScanDate = Date()
            isScanning = false
            if cancellation.isCancelled {
                didCancelScan = true
                scanProgress.phase = "Canceled"
            }
        }
    }

    func cancelAudit() {
        cancellation.cancel()
        scanProgress.phase = "Canceling"
    }

    func openFullDiskAccessSettings() {
        PermissionGuide.openFullDiskAccessSettings()
    }

    func dismissIssues() {
        scanIssues.removeAll()
    }

    func dismissCleanupResult() {
        cleanupResult = nil
    }

    func clearHistory() {
        historyStore.clear()
    }

    var hasRiskySelection: Bool {
        selectedFindings.contains { $0.risk == .review }
    }

    var totalHistoryBytes: Int64 {
        historyStore.records.reduce(0) { $0 + $1.reclaimedBytes }
    }

    var historyRecords: [CleanupHistoryRecord] {
        historyStore.records
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
            let movedFindings = draft.findings.filter { movedIDs.contains($0.id) }
            historyStore.record(result: result, movedFindings: movedFindings)
            findings.removeAll { movedIDs.contains($0.id) }
            selectedIDs.subtract(movedIDs)
        }
    }

    func exportAuditReport() {
        guard !findings.isEmpty else {
            reportExportResult = ReportExportResult(
                title: "No Report to Export",
                message: "Run a storage audit before exporting a report."
            )
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export nomospace Audit Report"
        panel.nameFieldStringValue = "nomospace-audit-report.md"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let report = AuditReport.render(
            findings: findings,
            issues: scanIssues,
            lastScanDate: lastScanDate,
            ruleCount: ruleCount,
            historyRecords: historyRecords
        )

        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            reportExportResult = ReportExportResult(
                title: "Report Exported",
                message: "Saved \(url.lastPathComponent)."
            )
        } catch {
            reportExportResult = ReportExportResult(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }

    func openTrash() {
        let trashURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash", isDirectory: true)
        NSWorkspace.shared.open(trashURL)
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

private final class ScanCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        cancelled = false
        lock.unlock()
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
