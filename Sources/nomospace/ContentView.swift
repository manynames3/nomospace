import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AuditViewModel()
    @State private var selectedSection: AppSection = .audit
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        NavigationSplitView {
            Sidebar(selectedSection: $selectedSection)
        } detail: {
            Group {
                switch selectedSection {
                case .audit:
                    AuditScreen(viewModel: viewModel)
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
        .onAppear {
            if hasSeenOnboarding && viewModel.findings.isEmpty {
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("nomospace")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Mac Storage Auditor")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 28)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.symbolName)
                                .frame(width: 18)
                            Text(section.rawValue)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedSection == section ? .primary : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedSection == section ? Color.primary.opacity(0.08) : .clear)
                    )
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Label("Trash-first cleanup", systemImage: "trash")
                Label("Risk-labeled findings", systemImage: "tag")
                Label("Exact path evidence", systemImage: "folder.badge.questionmark")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel()
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
    }
}

struct AuditScreen: View {
    @ObservedObject var viewModel: AuditViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AuditHeader(viewModel: viewModel)
                    if !hasSeenOnboarding {
                        OnboardingPanel(
                            runAudit: {
                                hasSeenOnboarding = true
                                viewModel.runAudit()
                            },
                            openFullDiskAccess: viewModel.openFullDiskAccessSettings,
                            dismiss: { hasSeenOnboarding = true }
                        )
                    }
                    SummaryGrid(viewModel: viewModel)
                    AuditHealthStrip(viewModel: viewModel)
                    FindingsToolbar(viewModel: viewModel)
                    if !viewModel.scanIssues.isEmpty {
                        ScanIssuesPanel(
                            issues: viewModel.scanIssues,
                            openFullDiskAccess: viewModel.openFullDiskAccessSettings,
                            dismiss: viewModel.dismissIssues
                        )
                    }

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
                .padding(28)
            }

            if !viewModel.selectedIDs.isEmpty {
                SelectionBar(viewModel: viewModel)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: viewModel.selectedIDs)
        .sheet(item: $viewModel.cleanupDraft) { draft in
            CleanupConfirmationView(
                draft: draft,
                cancel: { viewModel.cleanupDraft = nil },
                confirm: viewModel.moveDraftToTrash
            )
        }
        .alert(item: $viewModel.cleanupResult) { result in
            let message = result.failed.isEmpty
                ? "Moved \(result.movedCount) item(s) to Trash. Estimated reclaimed space: \(result.reclaimedBytes.storageString)."
                : "Moved \(result.movedCount) item(s) to Trash. \(result.failed.count) item(s) failed."

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
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Mac is full. nomospace shows exactly why.")
                    .font(.system(size: 30, weight: .semibold))
                Text("Find hidden System Data, app caches, developer artifacts, and storage bloat normal cleaners miss.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.runAudit()
            } label: {
                Label(viewModel.isScanning ? "Scanning" : "Run Storage Audit", systemImage: "magnifyingglass")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isScanning)
        }
    }
}

private struct OnboardingPanel: View {
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
                    Text("nomospace scans local folders, explains why storage is large, and moves selected items to Trash first. It does not upload file names, read browser passwords, or permanently delete without your action.")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                TrustPill(symbol: "externaldrive", title: "Find hidden System Data")
                TrustPill(symbol: "tag", title: "Risk-labeled cleanup")
                TrustPill(symbol: "trash", title: "Trash-first execution")
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
                    title: "Reclaimable",
                    value: viewModel.totalReclaimableBytes.storageString,
                    subtitle: "Items nomospace can move to Trash",
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
                    title: "Findings",
                    value: "\(viewModel.findings.count)",
                    subtitle: viewModel.lastScanDate.map { "Last scan \(Self.dateFormatter.string(from: $0))" } ?? "No scan yet",
                    symbol: "list.bullet.rectangle",
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 25, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
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
            HealthItem(symbol: "trash", title: "Trash-first cleanup", tint: AppTheme.accent)
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
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search apps, folders, file types, paths", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

                Button("Select Safe") {
                    viewModel.selectSafeFindings()
                }
                .disabled(viewModel.findings.isEmpty)

                Button("Clear") {
                    viewModel.clearSelection()
                }
                .disabled(viewModel.selectedIDs.isEmpty)

                Button {
                    viewModel.copySharableLink()
                } label: {
                    Label("Sharable Link", systemImage: "link")
                }

                Button {
                    viewModel.savePDFReport()
                } label: {
                    Label("Save PDF", systemImage: "doc.richtext")
                }
                .disabled(viewModel.findings.isEmpty || viewModel.isScanning)
            }

            HStack(spacing: 8) {
                ForEach(FindingFilter.allCases) { filter in
                    FilterChip(
                        title: filter.title,
                        isActive: viewModel.activeFilter == filter
                    ) {
                        viewModel.activeFilter = filter
                    }
                }
                Spacer()
                Text("\(viewModel.filteredFindings.count) result(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
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
                .font(.callout)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? AppTheme.accent.opacity(0.14) : Color.primary.opacity(0.06))
                )
                .foregroundStyle(isActive ? AppTheme.accent : .primary)
        }
        .buttonStyle(.plain)
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
