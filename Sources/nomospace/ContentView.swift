import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AuditViewModel
    @State private var selectedSection: AppSection
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    private let previewMode: Bool

    init(
        viewModel: AuditViewModel = AuditViewModel(),
        section: AppSection = .audit,
        previewMode: Bool = false
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _selectedSection = State(initialValue: section)
        self.previewMode = previewMode
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(selectedSection: $selectedSection)
                .background(AppTheme.ink.ignoresSafeArea())
        } detail: {
            Group {
                switch selectedSection {
                case .audit:
                    AuditScreen(viewModel: viewModel, previewMode: previewMode)
                case .history:
                    HistoryScreen(viewModel: viewModel)
                case .guide:
                    TrustGuideScreen(viewModel: viewModel)
                case .about:
                    AboutScreen(viewModel: viewModel)
                }
            }
            .background(AppTheme.page)
        }
        .tint(AppTheme.accent)
        .onAppear {
            if !previewMode && hasSeenOnboarding && viewModel.findings.isEmpty {
                viewModel.runAudit()
            }
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case audit = "Audit"
    case history = "History"
    case guide = "Guide"
    case about = "About"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .audit: "waveform.path.ecg.rectangle"
        case .history: "clock.arrow.circlepath"
        case .guide: "lock.shield"
        case .about: "info.circle"
        }
    }
}

private struct Sidebar: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                NomospaceMark(size: 35)
                VStack(alignment: .leading, spacing: 3) {
                    Text("nomospace")
                        .font(.system(size: 19, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(AppTheme.onDark)
                    Text("STORAGE INTELLIGENCE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AppTheme.onDarkMuted)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 34)
            .padding(.bottom, 31)
            .accessibilityElement(children: .combine)

            Rectangle().fill(AppTheme.darkLine)
                .frame(height: 1)
                .padding(.horizontal, 20)

            Text("WORKSPACE")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.onDarkMuted)
                .padding(.horizontal, 23)
                .padding(.top, 28)
                .padding(.bottom, 12)

            VStack(spacing: 5) {
                ForEach(AppSection.allCases) { section in
                    let isSelected = selectedSection == section
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(isSelected ? AppTheme.mint : .clear)
                                .frame(width: 3, height: 20)
                            Image(systemName: section.symbolName)
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 19)
                            Text(section.rawValue)
                                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                            Spacer()
                            if isSelected {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                            }
                        }
                        .foregroundStyle(isSelected ? AppTheme.onDark : AppTheme.onDarkMuted)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? AppTheme.darkLine : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityLabel("\(section.rawValue) section")
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.mint)
                Text("Your files stay yours.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.onDark)
                Text("Local audits. Explainable findings. Nothing deleted automatically.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.onDarkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.inkSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppTheme.darkLine, lineWidth: 1)
            )
            .padding(.horizontal, 13)

            HStack {
                Circle().fill(AppTheme.mint).frame(width: 5, height: 5)
                Text("ON-DEVICE / MACOS")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.onDarkMuted)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 237, max: 255)
    }
}

struct AuditScreen: View {
    @ObservedObject var viewModel: AuditViewModel
    var previewMode = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AuditHeader(viewModel: viewModel)
                    if !viewModel.scanIssues.isEmpty {
                        ScanIssuesPanel(
                            issues: viewModel.scanIssues,
                            openFullDiskAccess: viewModel.openFullDiskAccessSettings,
                            dismiss: viewModel.dismissIssues
                        )
                    } else if !hasSeenOnboarding && !previewMode {
                        OnboardingPanel(
                            isFullVersion: viewModel.isFullVersion,
                            runAudit: {
                                hasSeenOnboarding = true
                                viewModel.runAudit()
                            },
                            openFullDiskAccess: viewModel.openFullDiskAccessSettings,
                            dismiss: { hasSeenOnboarding = true }
                        )
                    } else if !viewModel.isFullVersion {
                        EvaluationModeBanner(viewModel: viewModel)
                    }
                    SummaryGrid(viewModel: viewModel)
                    FindingsToolbar(viewModel: viewModel)

                    if viewModel.isScanning {
                        ScanningState(
                            progress: viewModel.scanProgress,
                            cancel: viewModel.cancelAudit
                        )
                    } else if viewModel.findings.isEmpty {
                        EmptyState(
                            didCancel: viewModel.didCancelScan,
                            runAudit: viewModel.runAudit,
                            openFullDiskAccess: viewModel.openFullDiskAccessSettings
                        )
                    } else {
                        FindingsList(viewModel: viewModel)
                            .padding(.bottom, viewModel.selectedIDs.isEmpty ? 20 : 96)
                    }
                }
                .padding(25)
            }

            if !viewModel.selectedIDs.isEmpty {
                SelectionBar(viewModel: viewModel)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: viewModel.selectedIDs)
        .sheet(item: $viewModel.cleanupDraft) { draft in
            CleanupConfirmationView(
                draft: draft,
                cancel: { viewModel.cleanupDraft = nil },
                confirm: viewModel.moveDraftToTrash
            )
        }
        .sheet(item: $viewModel.lockedFeature) { feature in
            UnlockAccessView(viewModel: viewModel, feature: feature)
        }
        .alert(item: $viewModel.cleanupResult) { result in
            let message = result.failed.isEmpty
                ? "Moved \(result.movedCount) item(s) to Trash. Estimated contents moved: \(result.reclaimedBytes.storageString). Empty Trash to free space."
                : "Moved \(result.movedCount) item(s) to Trash. \(result.failed.count) item(s) were kept safe. \(result.failed.first?.1 ?? "")"

            return Alert(
                title: Text("Cleanup Finished"),
                message: Text(message),
                primaryButton: .default(Text("Open Trash")) {
                    viewModel.openTrash()
                },
                secondaryButton: .cancel(Text("Done"))
            )
        }
        .alert(item: $viewModel.reportExportResult) { result in
            Alert(
                title: Text(result.title),
                message: Text(result.message),
                dismissButton: .default(Text("Done"))
            )
        }
    }
}

private struct AuditHeader: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 25) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("MAC STORAGE  /  PRIVATE BY DESIGN")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(AppTheme.mint)
                    Text(viewModel.lastScanDate == nil
                         ? "See what uses your disk."
                         : "\(viewModel.findings.count) findings. Better clarity.")
                        .font(.system(size: 31, weight: .medium))
                        .tracking(-0.7)
                        .foregroundStyle(AppTheme.onDark)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Understand hidden storage, inspect each finding, and choose what is safe to move to Trash.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.onDarkMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 465, alignment: .leading)
                    Button {
                        viewModel.runAudit()
                    } label: {
                        Label(viewModel.isScanning ? "Scanning…" : "Run storage audit",
                              systemImage: "arrow.up.right")
                    }
                    .buttonStyle(HeroPrimaryButtonStyle())
                    .disabled(viewModel.isScanning)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                AuditStatusRail(viewModel: viewModel)
                    .frame(width: 189)
            }
            Rectangle().fill(AppTheme.darkLine).frame(height: 1)
            DiskCapacityStrip(available: viewModel.diskAvailableBytes,
                              total: viewModel.diskTotalBytes)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.ink)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.darkLine, lineWidth: 1)
        )
    }
}

private struct AuditStatusRail: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            status("RULE LIBRARY", "\(viewModel.ruleCount) rules")
            status("SCAN", viewModel.isScanning ? "In progress" : "Local only")
            status("ACCESS", viewModel.isFullVersion ? "Full access" : "Evaluation")
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.inkSecondary)
        .overlay(Rectangle().strokeBorder(AppTheme.darkLine, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func status(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.onDarkMuted)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.onDark)
                .lineLimit(1)
        }
    }
}

private struct DiskCapacityStrip: View {
    let available: Int64?
    let total: Int64?

    private var freeFraction: CGFloat? {
        guard let available, let total, total > 0 else { return nil }
        return CGFloat(min(max(Double(available) / Double(total), 0), 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 12) {
                Text("VOLUME CAPACITY")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.onDarkMuted)
                Spacer()
                if let available, let total {
                    Text("\(available.storageString) available  /  \(total.storageString) total")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.onDark)
                } else {
                    Text("Unable to read capacity")
                        .font(.caption).foregroundStyle(AppTheme.onDarkMuted)
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(AppTheme.darkLine)
                    if let freeFraction {
                        Rectangle()
                            .fill(AppTheme.mint)
                            .frame(width: geometry.size.width * freeFraction)
                    }
                }
            }
            .frame(height: 5)
            .accessibilityHidden(true)
            Text("Mint = macOS-estimated available capacity. File findings are estimates, not guaranteed recoverable space.")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.onDarkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HeroPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 19)
            .padding(.vertical, 12)
            .background(Capsule().fill(AppTheme.mint))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}

private struct OnboardingPanel: View {
    let isFullVersion: Bool
    let runAudit: () -> Void
    let openFullDiskAccess: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 7) {
                    Text("A storage audit, not a blind cleaner.")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(onboardingCopy)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                TrustPill(symbol: "externaldrive", title: "Find hidden System Data")
                TrustPill(symbol: "tag", title: "Risk-labeled cleanup")
                TrustPill(symbol: isFullVersion ? "trash" : "lock", title: isFullVersion ? "Trash-first execution" : "Access-code cleanup")
            }

            Text("For the most complete scan, enable Full Disk Access. If nomospace is not listed, drag the app into the Full Disk Access list, enable it, then rerun the audit.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("Open Full Disk Access", action: openFullDiskAccess)
                Spacer()
                Button("Skip for now", action: dismiss)
                Button("Run Audit", action: runAudit)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .panel()
    }

    private var onboardingCopy: String {
        if isFullVersion {
            return "nomospace scans local folders, explains why storage is large, and moves selected items to Trash first. It does not upload file names, read browser passwords, or permanently delete without your action."
        }
        return "nomospace scans local folders and explains why storage is large. Evaluation mode shows findings for free; an access code unlocks Trash-first cleanup and PDF reports."
    }
}

private struct TrustPill: View {
    let symbol: String
    let title: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            )
    }
}

private struct SummaryGrid: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                SummaryMetric(
                    title: "Potential cleanup",
                    value: viewModel.totalReclaimableBytes.storageString,
                    subtitle: viewModel.isFullVersion ? "Reviewable items, not yet freed space" : "Reviewable items after unlock",
                    symbol: "externaldrive.badge.checkmark",
                    tint: AppTheme.accent
                )
                SummaryMetric(
                    title: "Safe",
                    value: viewModel.safeBytes.storageString,
                    subtitle: "Caches and rebuildable storage",
                    symbol: "checkmark.shield",
                    tint: AppTheme.green
                )
                SummaryMetric(
                    title: "Review",
                    value: viewModel.reviewBytes.storageString,
                    subtitle: "Needs user judgment",
                    symbol: "exclamationmark.triangle",
                    tint: AppTheme.amber
                )
                SummaryMetric(
                    title: "Available on disk",
                    value: viewModel.diskAvailableBytes?.storageString ?? "Unavailable",
                    subtitle: "\(viewModel.findings.count) findings · macOS capacity estimate",
                    symbol: "externaldrive",
                    tint: .secondary
                )
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.65)
                    .foregroundStyle(AppTheme.textMuted)
                Spacer(minLength: 4)
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.system(size: 26, weight: .medium))
                .tracking(-0.65)
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textMuted)
                .lineLimit(2)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 114, alignment: .topLeading)
        .panel()
    }
}

private struct AuditHealthStrip: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        HStack(spacing: 12) {
            HealthItem(
                symbol: viewModel.ruleCount > 0 ? "checkmark.seal" : "exclamationmark.triangle",
                title: viewModel.ruleCount > 0 ? "\(viewModel.ruleCount) cleanup rules loaded" : "Rule library missing",
                tint: viewModel.ruleCount > 0 ? AppTheme.green : AppTheme.red
            )
            Divider()
                .frame(height: 20)
            HealthItem(symbol: "lock", title: "Local-only scan", tint: AppTheme.accent)
            Divider()
                .frame(height: 20)
            HealthItem(
                symbol: viewModel.isFullVersion ? "lock.open" : "lock",
                title: viewModel.isFullVersion ? "Full access unlocked" : "Cleanup locked",
                tint: viewModel.isFullVersion ? AppTheme.green : AppTheme.amber
            )
            Spacer()
            if !viewModel.scanIssues.isEmpty {
                Text("\(viewModel.scanIssues.count) skipped path(s)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.amber)
            }
        }
        .padding(12)
        .panel()
    }
}

private struct HealthItem: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(tint)
    }
}

private struct FindingsToolbar: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textMuted)
                    TextField("Search findings, paths, applications", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Search storage findings")
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(AppTheme.pageSecondary, in: RoundedRectangle(cornerRadius: 7))

                Button("Select safe") {
                    viewModel.selectSafeFindings()
                }
                .buttonStyle(BrandSecondaryButtonStyle())
                .disabled(viewModel.findings.isEmpty)

                Button("Clear") {
                    viewModel.clearSelection()
                }
                .disabled(viewModel.selectedIDs.isEmpty)

                Menu {
                    Button("Copy product link", action: viewModel.copySharableLink)
                    Button("Save PDF report", action: viewModel.savePDFReport)
                        .disabled(viewModel.findings.isEmpty || viewModel.isScanning)
                    if !viewModel.isFullVersion {
                        Button("Enter access code") { viewModel.requestUnlock() }
                    }
                } label: {
                    Label("More actions", systemImage: "ellipsis")
                }
                .accessibilityLabel("More audit actions")
            }

            HStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(FindingFilter.allCases) { filter in
                            FilterChip(
                                title: filter.title,
                                isActive: viewModel.activeFilter == filter
                            ) {
                                viewModel.activeFilter = filter
                            }
                        }
                    }
                }
                Text("\(viewModel.filteredFindings.count) results")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textMuted)
                    .fixedSize()
            }
        }
        .padding(13)
        .panel()
    }
}

private struct FilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isActive ? AppTheme.accentSubtle : AppTheme.pageSecondary)
                )
                .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct ScanningState: View {
    let progress: ScanProgress
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                VStack(alignment: .leading, spacing: 4) {
                    Text(progress.phase)
                        .font(.headline)
                    Text("\(progress.scannedItems) paths checked · \(progress.foundItems) findings")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: cancel)
            }

            if !progress.currentPath.isEmpty {
                Text(progress.currentPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text("Large folders can take a minute. Results are classified by known storage patterns and then grouped by cleanup risk.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .panel()
    }
}

private struct EmptyState: View {
    let didCancel: Bool
    let runAudit: () -> Void
    let openFullDiskAccess: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "externaldrive")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(didCancel ? "Audit canceled" : "Ready to audit this Mac")
                .font(.headline)
            Text(didCancel ? "Run the audit again when you are ready." : "Run a storage audit to find hidden app-generated storage. Grant Full Disk Access first for the most complete results.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Full Disk Access", action: openFullDiskAccess)
                Button("Run Storage Audit", action: runAudit)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .panel()
    }
}

private struct ScanIssuesPanel: View {
    let issues: [ScanIssue]
    let openFullDiskAccess: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(issues.count) path(s) were skipped", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(AppTheme.amber)
                Spacer()
                Button("Dismiss", action: dismiss)
                    .buttonStyle(.plain)
            }

            Text("This usually means macOS blocked access. Grant Full Disk Access for a more complete audit; if nomospace is not listed, drag the app into the Full Disk Access list.")
                .foregroundStyle(.secondary)

            ForEach(issues.prefix(3)) { issue in
                VStack(alignment: .leading, spacing: 3) {
                    Text(issue.path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(issue.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Open Full Disk Access", action: openFullDiskAccess)
        }
        .padding(14)
        .panel()
    }
}

#if DEBUG
/// Screenshot composition uses the same production SwiftUI components but
/// excludes macOS window-managed NavigationSplitView and scrolling, allowing
/// reproducible, accessible, labeled sample-data captures on CI machines.
struct NativePreviewLayout: View {
    @ObservedObject var viewModel: AuditViewModel
    let section: AppSection
    @State private var sidebarSelection: AppSection = .audit

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selectedSection: $sidebarSelection)
                .frame(width: 237)
                .frame(maxHeight: .infinity)
                .background(AppTheme.ink)

            VStack(alignment: .leading, spacing: 14) {
                if section == .audit {
                    AuditHeader(viewModel: viewModel)
                    EvaluationModeBanner(viewModel: viewModel)
                    SummaryGrid(viewModel: viewModel)
                    FindingsToolbar(viewModel: viewModel)
                    FindingsList(viewModel: viewModel)
                } else if section == .guide {
                    EditorialPageHeading(
                        eyebrow: "FINDINGS  /  INSPECTION",
                        title: "Storage findings",
                        subtitle: "Understand exactly what each app stored, how much it uses, and the cleanup risk."
                    )
                    FindingsToolbar(viewModel: viewModel)
                    FindingsList(viewModel: viewModel)
                }
                Spacer(minLength: 0)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.page)
        }
        .onAppear { sidebarSelection = section == .guide ? .audit : section }
    }
}
#endif
