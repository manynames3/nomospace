import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AuditViewModel()
    @State private var selectedSection = "Audit"

    var body: some View {
        NavigationSplitView {
            Sidebar(selectedSection: $selectedSection)
        } detail: {
            AuditScreen(viewModel: viewModel)
                .background(AppTheme.page)
        }
        .onAppear {
            if viewModel.findings.isEmpty {
                viewModel.runAudit()
            }
        }
    }
}

private struct Sidebar: View {
    @Binding var selectedSection: String

    private let sections = [
        ("Audit", "waveform.path.ecg.rectangle"),
        ("Findings", "list.bullet.rectangle"),
        ("Cleanup Plan", "checklist"),
        ("History", "clock.arrow.circlepath"),
        ("Rules", "slider.horizontal.3"),
        ("Settings", "gearshape")
    ]

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
                ForEach(sections, id: \.0) { title, symbol in
                    Button {
                        selectedSection = title
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: symbol)
                                .frame(width: 18)
                            Text(title)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedSection == title ? .primary : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedSection == title ? Color.primary.opacity(0.08) : .clear)
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

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AuditHeader(viewModel: viewModel)
                    SummaryGrid(viewModel: viewModel)
                    FindingsToolbar(viewModel: viewModel)

                    if viewModel.isScanning {
                        ScanningState()
                    } else if viewModel.findings.isEmpty {
                        EmptyState(runAudit: viewModel.runAudit)
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
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning hidden storage")
                .font(.headline)
            Text("Large folders can take a minute. nomospace is measuring real disk usage and classifying known storage patterns.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .panel()
    }
}

private struct EmptyState: View {
    let runAudit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "externaldrive")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No findings yet")
                .font(.headline)
            Text("Run a storage audit to find hidden app-generated storage and cleanup candidates.")
                .foregroundStyle(.secondary)
            Button("Run Storage Audit", action: runAudit)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .panel()
    }
}
