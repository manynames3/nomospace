import SwiftUI

struct FindingsList: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(viewModel.groupedFindings, id: \.0.id) { category, findings in
                FindingGroup(
                    category: category,
                    findings: findings,
                    viewModel: viewModel
                )
            }
        }
    }
}

private struct FindingGroup: View {
    let category: FindingCategory
    let findings: [StorageFinding]
    @ObservedObject var viewModel: AuditViewModel

    private var totalBytes: Int64 {
        findings.reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: category.symbolName)
                    .foregroundStyle(AppTheme.accent)
                Text(category.title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                Text("· \(findings.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textMuted)
                Spacer()
                Text(totalBytes.storageString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 4)
            .padding(.bottom, 3)

            VStack(spacing: 0) {
                ForEach(findings) { finding in
                    FindingRow(
                        finding: finding,
                        isSelected: viewModel.selectedIDs.contains(finding.id),
                        toggle: { viewModel.toggle(finding) },
                        reveal: { viewModel.revealInFinder(finding) }
                    )
                    if finding.id != findings.last?.id {
                        Rectangle()
                            .fill(AppTheme.border.opacity(0.7))
                            .frame(height: 1)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(AppTheme.border.opacity(0.9), lineWidth: 1)
            )
        }
    }
}

private struct FindingRow: View {
    let finding: StorageFinding
    let isSelected: Bool
    let toggle: () -> Void
    let reveal: () -> Void

    @State private var isExpanded = false
    @State private var isInspecting = false
    @State private var breakdown: FolderBreakdown?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Button(action: toggle) {
                    Image(systemName: checkboxSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isCleanable ? AppTheme.accent : .secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(!isCleanable)
                .help(isCleanable ? "Select for cleanup" : "Manual review only")
                .accessibilityLabel(isCleanable
                    ? "\(isSelected ? "Deselect" : "Select") \(finding.title), \(finding.sizeBytes.storageString), \(finding.risk.title)"
                    : "\(finding.title) is inspection-only")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(finding.title)
                            .font(.headline)
                            .lineLimit(2)

                        RiskBadge(risk: finding.risk)

                        Spacer()

                        Text(finding.sizeBytes.storageString)
                            .font(.system(.headline, design: .default))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }

                    Text(finding.explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)

                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(finding.path)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                VStack(spacing: 8) {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "Hide details" : "Show details")
                    .accessibilityLabel("\(isExpanded ? "Collapse" : "Expand") \(finding.title) details")

                    Button(action: reveal) {
                        Image(systemName: "arrow.up.forward.square")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                    .accessibilityLabel("Reveal \(finding.title) in Finder")
                }
            }
            .padding(14)

            if isExpanded {
                Divider()
                    .padding(.leading, 50)

                VStack(alignment: .leading, spacing: 10) {
                    DetailLine(title: "What happens if removed", value: finding.sideEffect)
                    DetailLine(title: "Source", value: finding.source)
                    DetailLine(title: "Risk rule", value: finding.risk.shortExplanation)
                    if finding.scanIncomplete {
                        DetailLine(title: "Scan completeness",
                                   value: "Incomplete. Re-run the scan after granting access; cleanup is blocked.")
                    }
                    Button {
                        isInspecting = true
                        Task {
                            breakdown = await FolderInspector.inspect(finding.url)
                            isInspecting = false
                        }
                    } label: {
                        Label(isInspecting ? "Inspecting..." : "Inspect contents",
                              systemImage: "folder.badge.questionmark")
                    }
                    .disabled(isInspecting)
                    .buttonStyle(.bordered)
                    if let breakdown {
                        Text("Largest inspected children (estimated allocated sizes)")
                            .font(.caption).fontWeight(.semibold)
                        ForEach(breakdown.children) { item in
                            HStack {
                                Text(item.name).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Text(item.sizeBytes.storageString).monospacedDigit()
                            }
                            .font(.caption)
                        }
                        if breakdown.totalChildren > breakdown.inspectedChildren {
                            Text("Partial view: inspected \(breakdown.inspectedChildren) of \(breakdown.totalChildren) items. Other folders may be larger.")
                                .font(.caption).foregroundStyle(AppTheme.textMuted)
                        }
                        if breakdown.skippedCount > 0 {
                            Text("\(breakdown.skippedCount) entries were inaccessible, linked, or only partially measured.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("APFS clones and system snapshots can make file totals differ from recoverable disk space.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 50)
                .padding(.trailing, 14)
                .padding(.vertical, 12)
                .transition(.opacity)
            }
        }
        .background(isSelected ? AppTheme.accentSubtle : AppTheme.panel)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(AppTheme.accent).frame(width: 3)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.17), value: isExpanded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.17), value: isSelected)
    }

    private var isCleanable: Bool {
        finding.risk.canMoveToTrash && CleanupSafety.refusalReason(for: finding) == nil
    }

    private var checkboxSymbol: String {
        if !isCleanable {
            return "minus.square"
        }
        return isSelected ? "checkmark.square.fill" : "square"
    }
}

private struct RiskBadge: View {
    let risk: RiskLevel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: risk.symbolName)
                .font(.caption)
            Text(risk.title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(risk.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(risk.tint.opacity(0.11))
        )
    }
}

private struct DetailLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
    }
}
