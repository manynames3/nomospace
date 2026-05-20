import SwiftUI

struct SelectionBar: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(viewModel.selectedIDs.count) item(s) selected")
                    .font(.headline)
                Text(selectionSubtitle)
                    .font(.callout)
                    .foregroundStyle(viewModel.hasRiskySelection ? AppTheme.amber : .secondary)
            }

            Spacer()

            Button("Clear") {
                viewModel.clearSelection()
            }

            Button {
                viewModel.prepareCleanup()
            } label: {
                Label(
                    viewModel.isFullVersion ? "Move to Trash" : "Unlock Cleanup",
                    systemImage: viewModel.isFullVersion ? "trash" : "lock"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }

    private var selectionSubtitle: String {
        if !viewModel.isFullVersion {
            return "\(viewModel.selectedBytes.storageString) selected · cleanup requires access code"
        }
        if viewModel.hasRiskySelection {
            return "\(viewModel.selectedBytes.storageString) selected · includes Review item(s)"
        }
        return "\(viewModel.selectedBytes.storageString) estimated reclaim"
    }
}

struct CleanupConfirmationView: View {
    let draft: CleanupDraft
    let cancel: () -> Void
    let confirm: () -> Void
    @State private var confirmedReviewRisk = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "trash")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Move selected items to Trash?")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("nomospace will move these items to Trash so you can restore them if needed. Empty Trash later to reclaim disk space permanently.")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                ConfirmationMetric(title: "Selected", value: "\(draft.findings.count)")
                ConfirmationMetric(title: "Estimated reclaim", value: draft.totalBytes.storageString)
                ConfirmationMetric(title: "Review items", value: draft.hasReviewItems ? "Yes" : "No")
            }

            if draft.hasReviewItems {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(AppTheme.amber)
                        Text("One or more selected items are marked Review. They may contain app state, browser data, or local content.")
                            .foregroundStyle(.secondary)
                    }

                    Toggle("I reviewed these paths and understand the side effects.", isOn: $confirmedReviewRisk)
                        .toggleStyle(.checkbox)
                }
                .padding(12)
                .panel()
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(draft.findings) { finding in
                        HStack(spacing: 10) {
                            Image(systemName: finding.risk.symbolName)
                                .foregroundStyle(finding.risk.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(finding.title)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text(finding.sideEffect)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text(finding.sizeBytes.storageString)
                                .monospacedDigit()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                }
            }
            .frame(maxHeight: 260)

            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button {
                    confirm()
                } label: {
                    Text("Move \(draft.findings.count) Item(s) to Trash")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.hasReviewItems && !confirmedReviewRisk)
            }
        }
        .padding(24)
        .frame(width: 660)
    }
}

private struct ConfirmationMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}
