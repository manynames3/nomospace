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
            HStack(spacing: 10) {
                Image(systemName: category.symbolName)
                    .foregroundStyle(AppTheme.accent)
                Text(category.title)
                    .font(.headline)
                Text(totalBytes.storageString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(findings) { finding in
                    FindingRow(
                        finding: finding,
                        isSelected: viewModel.selectedIDs.contains(finding.id),
                        toggle: { viewModel.toggle(finding) },
                        reveal: { viewModel.revealInFinder(finding) }
                    )
                }
            }
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

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(finding.title)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        RiskBadge(risk: finding.risk)

                        Spacer()

                        Text(finding.sizeBytes.storageString)
                            .font(.system(.headline, design: .rounded))
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
                            .font(.caption)
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

                    Button(action: reveal) {
                        Image(systemName: "arrow.up.forward.square")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
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
                                .font(.caption).foregroundStyle(.orange)
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isSelected ? 0.055 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? AppTheme.accent.opacity(0.6) : AppTheme.border, lineWidth: 1)
        )
        .animation(.snappy, value: isExpanded)
        .animation(.snappy, value: isSelected)
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
            Capsule()
                .fill(risk.tint.opacity(0.12))
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
