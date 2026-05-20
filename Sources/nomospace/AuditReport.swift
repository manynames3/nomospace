import Foundation

enum AuditReport {
    static func render(
        findings: [StorageFinding],
        issues: [ScanIssue],
        lastScanDate: Date?,
        ruleCount: Int,
        historyRecords: [CleanupHistoryRecord]
    ) -> String {
        let generatedAt = dateTimeFormatter.string(from: Date())
        let scannedAt = lastScanDate.map(dateTimeFormatter.string) ?? "Not scanned yet"
        let sortedFindings = findings.sorted { $0.sizeBytes > $1.sizeBytes }
        let totalReclaimable = findings
            .filter { $0.risk != .protected }
            .reduce(0) { $0 + $1.sizeBytes }
        let safeBytes = findings
            .filter { $0.risk == .safe || $0.risk == .usuallySafe }
            .reduce(0) { $0 + $1.sizeBytes }
        let reviewBytes = findings
            .filter { $0.risk == .review }
            .reduce(0) { $0 + $1.sizeBytes }
        let protectedBytes = findings
            .filter { $0.risk == .protected }
            .reduce(0) { $0 + $1.sizeBytes }

        var lines: [String] = [
            "# nomospace Storage Audit Report",
            "",
            "Generated: \(generatedAt)",
            "Last scan: \(scannedAt)",
            "Rule library: \(ruleCount) bundled cleanup rules loaded",
            "",
            "## Privacy",
            "",
            "This report was generated locally. nomospace does not upload file names, paths, browser data, cleanup history, or scan results.",
            "",
            "## Summary",
            "",
            "- Findings: \(findings.count)",
            "- Reclaimable: \(totalReclaimable.storageString)",
            "- Safe / usually safe: \(safeBytes.storageString)",
            "- Review: \(reviewBytes.storageString)",
            "- Protected visibility-only: \(protectedBytes.storageString)",
            "- Skipped paths: \(issues.count)",
            ""
        ]

        if sortedFindings.isEmpty {
            lines.append("## Findings")
            lines.append("")
            lines.append("No findings were available when this report was exported.")
        } else {
            lines.append("## Findings")
            lines.append("")

            for finding in sortedFindings {
                lines.append("### \(finding.title)")
                lines.append("")
                lines.append("- Size: \(finding.sizeBytes.storageString)")
                lines.append("- Risk: \(finding.risk.title)")
                lines.append("- Category: \(finding.category.title)")
                lines.append("- Source: \(finding.source)")
                lines.append("- Path: `\(finding.path)`")
                lines.append("- Explanation: \(finding.explanation)")
                lines.append("- Side effect: \(finding.sideEffect)")
                lines.append("")
            }
        }

        if !issues.isEmpty {
            lines.append("## Skipped Paths")
            lines.append("")
            lines.append("These paths were skipped or partially inaccessible. Grant Full Disk Access and rerun the audit if the result looks incomplete.")
            lines.append("")

            for issue in issues {
                lines.append("- `\(issue.path)`: \(issue.message)")
            }
            lines.append("")
        }

        if !historyRecords.isEmpty {
            lines.append("## Cleanup History")
            lines.append("")

            for record in historyRecords.prefix(10) {
                let date = dateTimeFormatter.string(from: record.date)
                lines.append("- \(date): \(record.reclaimedBytes.storageString) moved to Trash across \(record.movedCount) item(s)")
            }
            lines.append("")
        }

        lines.append("## Recommended Demo Cleanup")
        lines.append("")
        lines.append("For a safe live demo, select only findings marked Safe or Usually Safe, then move them to Trash. Review and protected findings should be inspected manually.")

        return lines.joined(separator: "\n")
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
