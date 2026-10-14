import SwiftUI

struct SelectionBar: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(viewModel.selectedIDs.count) selected for review")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.onDark)
                Text(selectionSubtitle)
                    .font(.callout)
                    .foregroundStyle(viewModel.hasRiskySelection ? Color(red: 0.95, green: 0.75, blue: 0.47) : AppTheme.onDarkMuted)
            }

            Spacer()

            Button("Clear") {
                viewModel.clearSelection()
            }
            .foregroundStyle(AppTheme.onDarkMuted)

            Button {
                viewModel.prepareCleanup()
            } label: {
                Label(
                    viewModel.isFullVersion ? "Review & Move to Trash…" : "Unlock Cleanup",
                    systemImage: viewModel.isFullVersion ? "trash" : "lock"
                )
            }
            .buttonStyle(HeroDockButtonStyle())
        }
        .padding(16)
        .background(AppTheme.ink)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppTheme.darkLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 16, y: 7)
    }

    private var selectionSubtitle: String {
        if !viewModel.isFullVersion {
            return "\(viewModel.selectedBytes.storageString) estimated contents · unlock required"
        }
        if viewModel.hasRiskySelection {
            return "\(viewModel.selectedBytes.storageString) estimated · includes Review item(s)"
        }
        return "\(viewModel.selectedBytes.storageString) estimated contents · space freed after Empty Trash"
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
                    .foregroundStyle(AppTheme.textMuted)
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

            HStack(spacing: 8) {
                workflowStep("1", "SELECTED", "Reviewed files")
                Image(systemName: "arrow.right").foregroundStyle(AppTheme.textMuted)
                workflowStep("2", "MAC TRASH", "Recoverable")
                Image(systemName: "arrow.right").foregroundStyle(AppTheme.textMuted)
                workflowStep("3", "EMPTY TRASH", "Frees space")
            }
            .padding(12)
            .background(AppTheme.pageSecondary, in: RoundedRectangle(cornerRadius: 9))

            HStack(spacing: 12) {
                ConfirmationMetric(title: "Selected", value: "\(draft.findings.count)")
                ConfirmationMetric(title: "Estimated contents to Trash", value: draft.totalBytes.storageString)
                ConfirmationMetric(title: "Requires review", value: "\(draft.findings.filter { $0.risk == .review }.count)")
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
                .buttonStyle(BrandPrimaryButtonStyle())
                .disabled(draft.hasReviewItems && !confirmedReviewRisk)
            }
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 660, maxWidth: 720)
    }

    private func workflowStep(_ number: String, _ heading: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(number) / \(heading)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeroDockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Capsule().fill(AppTheme.mint))
            .opacity(configuration.isPressed ? 0.75 : 1)
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
