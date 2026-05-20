import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var viewModel: AuditViewModel
    @State private var isConfirmingClearHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cleanup History")
                            .font(.system(size: 30, weight: .semibold))
                        Text("A local record of items moved to Trash from this Mac. This never leaves the device.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clear History") {
                        isConfirmingClearHistory = true
                    }
                    .disabled(viewModel.historyRecords.isEmpty || !viewModel.isFullVersion)
                }

                if !viewModel.isFullVersion {
                    LockedFeaturePanel(
                        title: "Cleanup history is a full-access feature",
                        message: "Evaluation mode can run audits and show findings. Enter an access code to enable Trash-first cleanup and the local receipts that appear here.",
                        primaryAction: { viewModel.requestUnlock() },
                        secondaryAction: viewModel.openAccessCodeRequest
                    )
                }

                SummaryMetricRow(
                    title: "Total moved to Trash",
                    value: viewModel.totalHistoryBytes.storageString,
                    subtitle: "\(viewModel.historyRecords.count) cleanup run(s)"
                )

                if viewModel.historyRecords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text("No cleanup history yet")
                            .font(.headline)
                        Text("After you move selected findings to Trash, nomospace will keep a local receipt here.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .panel()
                } else {
                    VStack(spacing: 10) {
                        ForEach(viewModel.historyRecords) { record in
                            HistoryRow(record: record)
                        }
                    }
                }
            }
            .padding(28)
        }
        .alert("Clear cleanup history?", isPresented: $isConfirmingClearHistory) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("This removes local cleanup receipts from nomospace. It does not change anything in Trash.")
        }
    }
}

struct TrustGuideScreen: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("How nomospace keeps cleanup safe")
                        .font(.system(size: 30, weight: .semibold))
                    Text("The product is designed to explain storage before it removes anything.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    GuideCard(
                        symbol: "lock.shield",
                        title: "Local-only audit",
                        copy: "nomospace scans folders on this Mac. It does not upload your file names, browser data, or cleanup history."
                    )
                    GuideCard(
                        symbol: viewModel.ruleCount > 0 ? "checkmark.seal" : "exclamationmark.triangle",
                        title: viewModel.ruleCount > 0 ? "Rule library loaded" : "Rule library unavailable",
                        copy: viewModel.ruleCount > 0
                            ? "\(viewModel.ruleCount) bundled cleanup rules are available in this build."
                            : "The cleanup rule library did not load. Use the packaged app or reinstall before relying on results."
                    )
                    GuideCard(
                        symbol: "tag",
                        title: "Risk labels before action",
                        copy: "Safe items are rebuildable caches. Review items may contain app state or browser data and require extra confirmation."
                    )
                    GuideCard(
                        symbol: "trash",
                        title: viewModel.isFullVersion ? "Trash first" : "Cleanup unlock",
                        copy: viewModel.isFullVersion
                            ? "Cleanup moves items to macOS Trash. Empty Trash later when you are comfortable with the result."
                            : "Evaluation mode shows what nomospace found. Enter an access code to enable Trash-first cleanup."
                    )
                    GuideCard(
                        symbol: "folder.badge.questionmark",
                        title: "Full Disk Access improves accuracy",
                        copy: "macOS may block parts of Desktop, Documents, Downloads, or app containers. If nomospace is not listed in Full Disk Access, drag the app into the list, enable it, then rerun the audit."
                    )
                }

                HStack {
                    Button("Open Full Disk Access", action: viewModel.openFullDiskAccessSettings)
                    Button("Run Audit", action: viewModel.runAudit)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
        }
    }
}

struct AboutScreen: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("About nomospace")
                        .font(.system(size: 30, weight: .semibold))
                    Text("A local-first Mac Storage Auditor for hidden storage that normal cleaners miss.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    AboutStatusRow(
                        title: "Version",
                        status: "0.1.0 beta",
                        symbol: "shippingbox",
                        tint: AppTheme.accent,
                        detail: "This direct-download build is suitable for controlled demos and beta testing."
                    )
                    AboutStatusRow(
                        title: "Access",
                        status: viewModel.accessStatusTitle,
                        symbol: viewModel.isFullVersion ? "lock.open" : "lock",
                        tint: viewModel.isFullVersion ? AppTheme.green : AppTheme.amber,
                        detail: viewModel.accessStatusDetail
                    )
                    AboutStatusRow(
                        title: "Local scan and risk labels",
                        status: "Included",
                        symbol: "checkmark.circle",
                        tint: AppTheme.green,
                        detail: "Evaluation mode can scan this Mac, explain findings, show exact paths, and label cleanup risk."
                    )
                    AboutStatusRow(
                        title: "Trash-first cleanup",
                        status: viewModel.isFullVersion ? "Unlocked" : "Locked",
                        symbol: viewModel.isFullVersion ? "checkmark.circle" : "lock",
                        tint: viewModel.isFullVersion ? AppTheme.green : AppTheme.amber,
                        detail: "Selected cleanup items move to macOS Trash first. This requires full access."
                    )
                    AboutStatusRow(
                        title: "PDF audit report",
                        status: viewModel.isFullVersion ? (viewModel.findings.isEmpty ? "Run audit first" : "Ready") : "Locked",
                        symbol: viewModel.isFullVersion ? (viewModel.findings.isEmpty ? "doc.badge.clock" : "checkmark.circle") : "lock",
                        tint: viewModel.isFullVersion ? (viewModel.findings.isEmpty ? AppTheme.amber : AppTheme.green) : AppTheme.amber,
                        detail: "Reports can be saved as PDF for customer support, family tech help, or before/after proof. This requires full access."
                    )
                    AboutStatusRow(
                        title: "Rule library",
                        status: viewModel.ruleCount > 0 ? "\(viewModel.ruleCount) rules loaded" : "Missing",
                        symbol: viewModel.ruleCount > 0 ? "checkmark.circle" : "xmark.octagon",
                        tint: viewModel.ruleCount > 0 ? AppTheme.green : AppTheme.red,
                        detail: "Bundled rules are validated by the app self-test and package script."
                    )
                    AboutStatusRow(
                        title: "Direct distribution",
                        status: "Needs notarization",
                        symbol: "seal",
                        tint: AppTheme.amber,
                        detail: "A public website download should be Developer ID signed, notarized, zipped or packaged as a DMG, and tested on real customer Macs."
                    )
                }

                HStack {
                    Button {
                        viewModel.copySharableLink()
                    } label: {
                        Label("Sharable Link", systemImage: "link")
                    }

                    Button {
                        viewModel.savePDFReport()
                    } label: {
                        Label("Save PDF", systemImage: viewModel.isFullVersion ? "doc.richtext" : "lock")
                    }
                    .disabled(viewModel.findings.isEmpty)

                    if !viewModel.isFullVersion {
                        Button {
                            viewModel.requestUnlock()
                        } label: {
                            Label("Enter Code", systemImage: "key")
                        }
                    }

                    Button("Run Audit", action: viewModel.runAudit)
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isScanning)
                }
            }
            .padding(28)
        }
    }
}

private struct AboutStatusRow: View {
    let title: String
    let status: String
    let symbol: String
    let tint: Color
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(status)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(tint)
                }
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .panel()
    }
}

private struct SummaryMetricRow: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .panel()
    }
}

private struct HistoryRow: View {
    let record: CleanupHistoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.reclaimedBytes.storageString)
                    .font(.headline)
                Text("moved to Trash")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Self.formatter.string(from: record.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(record.itemTitles.prefix(4).joined(separator: ", "))
                .font(.callout)
                .lineLimit(2)
        }
        .padding(14)
        .panel()
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct GuideCard: View {
    let symbol: String
    let title: String
    let copy: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(copy)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .panel()
    }
}
