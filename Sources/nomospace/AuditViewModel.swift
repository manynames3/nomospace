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
    @Published var lockedFeature: LockedFeature?
    @Published private(set) var isFullVersion: Bool
    @Published private(set) var activatedAt: Date?
    @Published var lastScanDate: Date?
    @Published private(set) var diskAvailableBytes: Int64?
    @Published private(set) var diskTotalBytes: Int64?
    @Published var didCancelScan = false

    private let scanner: StorageScanner
    private let cancellation = ScanCancellation()
    private let licenseStore: LicenseStore
    let historyStore: HistoryStore

    init(
        scanner: StorageScanner = StorageScanner(),
        historyStore: HistoryStore = HistoryStore(),
        licenseStore: LicenseStore = LicenseStore()
    ) {
        self.scanner = scanner
        self.historyStore = historyStore
        self.licenseStore = licenseStore
        self.isFullVersion = licenseStore.isFullAccessEnabled
        self.activatedAt = licenseStore.activatedAt
        self.diskAvailableBytes = VolumeMetrics.availableBytes()
        self.diskTotalBytes = VolumeMetrics.totalBytes()
    }

    #if DEBUG
    /// Explicitly synthetic, read-only UI fixtures. Never used during a real audit.
    func loadPreviewFixtures() {
        let home = "/Users/demo"
        let specimens: [(String, String, Int64, FindingCategory, RiskLevel, String)] = [
            ("Adobe Camera Raw Cache", "Library/Caches/Adobe/CameraRaw", 14_500_000_000, .adobePhoto, .safe,
             "Cached previews and image-processing assets from photo workflows."),
            ("Lightroom Preview Cache", "Pictures/Lightroom/Previews", 8_280_000_000, .adobePhoto, .review,
             "Large preview catalogs and rendered image thumbnails."),
            ("Xcode Derived Data", "Library/Developer/Xcode/DerivedData", 12_100_000_000, .developer, .usuallySafe,
             "Intermediate build results generated while developing applications."),
            ("AI Model Downloads", ".cache/huggingface/hub", 21_700_000_000, .developer, .review,
             "Locally downloaded models that may be needed offline."),
            ("Homebrew Cache", "Library/Caches/Homebrew", 3_250_000_000, .developer, .usuallySafe,
             "Downloaded installers and metadata for developer tools."),
            ("Browser Site Data", "Library/Application Support/Google/Chrome", 5_600_000_000, .browser, .protected,
             "Personal browser profiles and sign-in state, shown for visibility only.")
        ]
        findings = specimens.map { title, relative, size, category, risk, explanation in
            let url = URL(fileURLWithPath: home).appendingPathComponent(relative)
            return StorageFinding(
                id: relative, title: title, sizeBytes: size, url: url,
                category: category, risk: risk, explanation: explanation,
                sideEffect: "Inspect before taking action.",
                source: "Illustrative sample"
            )
        }
        diskTotalBytes = 512_000_000_000
        diskAvailableBytes = 186_000_000_000
        lastScanDate = Date(timeIntervalSince1970: 1_781_200_000)
        scanIssues = []
        searchText = ""
        activeFilter = .all
        isScanning = false
    }
    #endif

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
            .filter { $0.risk != .protected && CleanupSafety.refusalReason(for: $0) == nil }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var safeBytes: Int64 {
        findings
            .filter {
                ($0.risk == .safe || $0.risk == .usuallySafe)
                    && CleanupSafety.refusalReason(for: $0) == nil
            }
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
            diskAvailableBytes = VolumeMetrics.availableBytes()
            diskTotalBytes = VolumeMetrics.totalBytes()
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

    var accessStatusTitle: String {
        isFullVersion ? "Full Access" : "Evaluation Mode"
    }

    var accessStatusDetail: String {
        if isFullVersion {
            return "Cleanup, PDF reports, and local history are unlocked on this Mac."
        }
        return "Audits and findings are free. Cleanup and PDF reports require an access code."
    }

    func toggle(_ finding: StorageFinding) {
        guard finding.risk.canMoveToTrash,
              CleanupSafety.refusalReason(for: finding) == nil else { return }
        if selectedIDs.contains(finding.id) {
            selectedIDs.remove(finding.id)
        } else {
            selectedIDs.insert(finding.id)
        }
    }

    func selectSafeFindings() {
        selectedIDs = Set(
            findings
                .filter { $0.risk.allowsDefaultSelection && $0.risk.canMoveToTrash && CleanupSafety.refusalReason(for: $0) == nil }
                .map(\.id)
        )
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func prepareCleanup() {
        guard requireFullVersion(.cleanup) else { return }
        let selected = selectedFindings.filter {
            $0.risk.canMoveToTrash && CleanupSafety.refusalReason(for: $0) == nil
        }
        guard !selected.isEmpty else { return }
        cleanupDraft = CleanupDraft(findings: selected)
    }

    func moveDraftToTrash() {
        guard requireFullVersion(.cleanup) else { return }
        guard let draft = cleanupDraft else { return }
        cleanupDraft = nil

        Task {
            let result = await TrashMover.moveToTrash(draft.findings)
            cleanupResult = result
            diskAvailableBytes = VolumeMetrics.availableBytes()

            let movedIDs = Set(draft.findings.map(\.id)).subtracting(result.failed.map { $0.0.id })
            let movedFindings = draft.findings.filter { movedIDs.contains($0.id) }
            historyStore.record(result: result, movedFindings: movedFindings)
            findings.removeAll { movedIDs.contains($0.id) }
            selectedIDs.subtract(movedIDs)
        }
    }

    func copySharableLink() {
        let url = "https://nomospace.pages.dev"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        reportExportResult = ReportExportResult(
            title: "Sharable Link Copied",
            message: "Copied \(url)."
        )
    }

    func savePDFReport() {
        guard !findings.isEmpty else {
            reportExportResult = ReportExportResult(
                title: "No PDF to Save",
                message: "Run a storage audit before saving a PDF report."
            )
            return
        }

        guard requireFullVersion(.pdf) else { return }

        let panel = NSSavePanel()
        panel.title = "Save nomospace Audit PDF"
        panel.nameFieldStringValue = "nomospace-audit-report.pdf"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.pdf]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try AuditReport.writePDF(
                findings: findings,
                issues: scanIssues,
                lastScanDate: lastScanDate,
                ruleCount: ruleCount,
                historyRecords: historyRecords,
                to: url
            )
            reportExportResult = ReportExportResult(
                title: "PDF Saved",
                message: "Saved \(url.lastPathComponent)."
            )
        } catch {
            reportExportResult = ReportExportResult(
                title: "Save Failed",
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

    func requestUnlock(for feature: LockedFeature = .fullAccess) {
        lockedFeature = feature
    }

    func dismissUnlockPrompt() {
        lockedFeature = nil
    }

    @discardableResult
    func activateFullVersion(code: String) -> Bool {
        guard licenseStore.activate(code: code) else { return false }
        isFullVersion = true
        activatedAt = licenseStore.activatedAt
        lockedFeature = nil
        reportExportResult = ReportExportResult(
            title: "Full Access Unlocked",
            message: "Cleanup, PDF reports, and cleanup history are now enabled on this Mac."
        )
        return true
    }

    func openAccessCodeRequest() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "aidenrhaacloud@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "nomospace access code"),
            URLQueryItem(
                name: "body",
                value: "Hi, I would like a nomospace access code for the direct-download Mac app."
            )
        ]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
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

    private func requireFullVersion(_ feature: LockedFeature) -> Bool {
        guard isFullVersion else {
            lockedFeature = feature
            return false
        }
        return true
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
                // Always revalidate at the deletion sink. A rule label or an earlier
                // preview cannot make a now-unsafe or symlinked path deletable.
                if let reason = CleanupSafety.refusalReason(for: finding, checkProcesses: true) {
                    failed.append((finding, reason))
                    continue
                }
                do {
                    var resultingURL: NSURL?
                    try fileManager.trashItem(
                        at: finding.url,
                        resultingItemURL: &resultingURL
                    )
                    movedCount += 1
                    // This is content moved, not disk space freed: Trash still uses disk.
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
