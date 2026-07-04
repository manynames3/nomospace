import Foundation

struct StorageRule: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let relativePath: String
    let category: FindingCategory
    let risk: RiskLevel
    let explanation: String
    let sideEffect: String
    let source: String
    let minimumBytes: Int64

    func url(relativeTo homeURL: URL) -> URL {
        homeURL.appendingPathComponent(relativePath)
    }

    func finding(homeURL: URL, sizeBytes: Int64) -> StorageFinding {
        let resolvedURL = url(relativeTo: homeURL)
        return StorageFinding(
            id: resolvedURL.standardizedFileURL.path,
            title: title,
            sizeBytes: sizeBytes,
            url: resolvedURL,
            category: category,
            risk: risk,
            explanation: explanation,
            sideEffect: sideEffect,
            source: source
        )
    }

    static func bundledRules() -> [StorageRule] {
        guard let url = ruleFileCandidates().first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([StorageRule].self, from: data)
        } catch {
            return []
        }
    }

    private static func ruleFileCandidates() -> [URL] {
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(
                resourceURL
                    .appendingPathComponent("nomospace_nomospace.bundle")
                    .appendingPathComponent("storage-rules.json")
            )
        }

        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            candidates.append(
                executableDirectory
                    .appendingPathComponent("nomospace_nomospace.bundle")
                    .appendingPathComponent("storage-rules.json")
            )
        }

        candidates.append(
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/nomospace/Resources/Rules/storage-rules.json")
        )

        return candidates
    }
}

struct StorageScanner: Sendable {
    let homeURL: URL
    let rules: [StorageRule]

    init(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        rules: [StorageRule] = StorageRule.bundledRules()
    ) {
        self.homeURL = homeURL
        self.rules = rules
    }

    func scan(
        progressHandler: @Sendable @escaping (ScanProgress) -> Void = { _ in },
        shouldCancel: @Sendable @escaping () -> Bool = { false }
    ) async -> ScanReport {
        let homeURL = homeURL
        let rules = rules

        return await Task.detached(priority: .userInitiated) {
            var findings: [StorageFinding] = []
            var issues: [ScanIssue] = []
            var knownExistingPaths = Set<String>()
            var progress = ScanProgress(
                phase: "Checking known storage patterns",
                currentPath: "",
                scannedItems: 0,
                foundItems: 0
            )

            func emit(_ phase: String, _ path: String = "") {
                progress.phase = phase
                progress.currentPath = path
                progress.scannedItems += 1
                progress.foundItems = findings.count
                progressHandler(progress)
            }

            for rule in rules {
                guard !shouldCancel() else {
                    return ScanReport(findings: findings.withoutNestedDuplicates(), issues: issues)
                }

                let url = rule.url(relativeTo: homeURL)
                emit("Checking known storage patterns", url.path)
                guard url.exists else { continue }

                let result = DirectorySizer.allocatedSize(at: url)
                issues.append(contentsOf: result.issues)
                guard result.sizeBytes >= rule.minimumBytes else { continue }

                knownExistingPaths.insert(url.standardizedFileURL.path)
                findings.append(rule.finding(homeURL: homeURL, sizeBytes: result.sizeBytes))
            }

            guard !shouldCancel() else {
                return ScanReport(findings: findings.withoutNestedDuplicates(), issues: issues)
            }

            let appSupport = scanLargeChildren(
                parent: homeURL.appendingPathComponent("Library/Application Support"),
                category: .appData,
                risk: .review,
                minimumBytes: 750.megabytes,
                source: "Application Support",
                knownSpecificPaths: knownExistingPaths,
                progress: { path in emit("Scanning Application Support", path) },
                shouldCancel: shouldCancel
            )
            findings.append(contentsOf: appSupport.findings)
            issues.append(contentsOf: appSupport.issues)

            guard !shouldCancel() else {
                return ScanReport(findings: findings.withoutNestedDuplicates(), issues: issues)
            }

            let caches = scanLargeChildren(
                parent: homeURL.appendingPathComponent("Library/Caches"),
                category: .cache,
                risk: .safe,
                minimumBytes: 250.megabytes,
                source: "User Cache",
                knownSpecificPaths: knownExistingPaths,
                progress: { path in emit("Scanning caches", path) },
                shouldCancel: shouldCancel
            )
            findings.append(contentsOf: caches.findings)
            issues.append(contentsOf: caches.issues)

            let personal = scanPersonalFolders(
                homeURL: homeURL,
                knownSpecificPaths: knownExistingPaths,
                progress: { path in emit("Checking personal folders", path) },
                shouldCancel: shouldCancel
            )
            findings.append(contentsOf: personal.findings)
            issues.append(contentsOf: personal.issues)

            progress.phase = "Finished"
            progress.currentPath = ""
            progress.foundItems = findings.count
            progressHandler(progress)

            return ScanReport(
                findings: findings
                    .withoutNestedDuplicates()
                    .sorted { lhs, rhs in
                        if lhs.sizeBytes == rhs.sizeBytes {
                            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                        }
                        return lhs.sizeBytes > rhs.sizeBytes
                    },
                issues: Array(issues.prefix(50))
            )
        }.value
    }
}

private struct ScanSectionResult: Sendable {
    let findings: [StorageFinding]
    let issues: [ScanIssue]
}

private func scanLargeChildren(
    parent: URL,
    category: FindingCategory,
    risk: RiskLevel,
    minimumBytes: Int64,
    source: String,
    knownSpecificPaths: Set<String>,
    progress: (String) -> Void,
    shouldCancel: () -> Bool
) -> ScanSectionResult {
    guard parent.exists else {
        return ScanSectionResult(findings: [], issues: [])
    }

    let children: [URL]
    do {
        children = try FileManager.default.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
    } catch {
        return ScanSectionResult(
            findings: [],
            issues: [
                ScanIssue(path: parent.path, message: "Unable to inspect: \(error.localizedDescription)")
            ]
        )
    }

    var findings: [StorageFinding] = []
    var issues: [ScanIssue] = []

    for child in children {
        guard !shouldCancel() else { break }
        progress(child.path)

        let standardizedPath = child.standardizedFileURL.path
        guard !knownSpecificPaths.contains(standardizedPath) else { continue }
        guard !knownSpecificPaths.contains(where: { knownPath in
            knownPath.hasPrefix(standardizedPath + "/")
        }) else { continue }

        let result = DirectorySizer.allocatedSize(at: child)
        issues.append(contentsOf: result.issues)
        guard result.sizeBytes >= minimumBytes else { continue }

        findings.append(StorageFinding(
            id: standardizedPath,
            title: child.lastPathComponent,
            sizeBytes: result.sizeBytes,
            url: child,
            category: category,
            risk: risk,
            explanation: "Large storage under \(source). This may be cache, app state, local content, or downloaded resources.",
            sideEffect: risk == .safe
                ? "The app may rebuild these files later."
                : "Review this path before selecting it. It may contain app state or local user data.",
            source: source
        ))
    }

    return ScanSectionResult(findings: findings, issues: Array(issues.prefix(30)))
}

private func scanPersonalFolders(
    homeURL: URL,
    knownSpecificPaths: Set<String>,
    progress: (String) -> Void,
    shouldCancel: () -> Bool
) -> ScanSectionResult {
    let folders: [(String, FindingCategory, RiskLevel, String)] = [
        ("Desktop", .personal, .protected, "Desktop files are usually personal or active work."),
        ("Downloads", .personal, .review, "Downloads may contain installers, exports, documents, and media."),
        ("Documents", .personal, .protected, "Documents usually contains personal or project files."),
        ("Pictures", .media, .protected, "Pictures may contain photo libraries or personal media."),
        ("Movies", .media, .protected, "Movies may contain personal media and exports."),
        ("Aftershoot Projects", .media, .protected, "Aftershoot projects may contain active photo work.")
    ]

    var findings: [StorageFinding] = []
    var issues: [ScanIssue] = []

    for (name, category, risk, explanation) in folders {
        guard !shouldCancel() else { break }

        let url = homeURL.appendingPathComponent(name)
        progress(url.path)
        let standardizedPath = url.standardizedFileURL.path
        guard url.exists else { continue }
        guard !knownSpecificPaths.contains(standardizedPath) else { continue }

        let result = DirectorySizer.allocatedSize(at: url)
        issues.append(contentsOf: result.issues)
        guard result.sizeBytes >= 500.megabytes else { continue }

        findings.append(StorageFinding(
            id: standardizedPath,
            title: name,
            sizeBytes: result.sizeBytes,
            url: url,
            category: category,
            risk: risk,
            explanation: explanation,
            sideEffect: "Use Reveal in Finder and decide manually. nomospace does not auto-select personal folders.",
            source: "Home Folder"
        ))
    }

    return ScanSectionResult(findings: findings, issues: Array(issues.prefix(30)))
}

private struct DirectorySizeResult: Sendable {
    let sizeBytes: Int64
    let issues: [ScanIssue]
}

private enum DirectorySizer {
    static func allocatedSize(at url: URL) -> DirectorySizeResult {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return DirectorySizeResult(sizeBytes: 0, issues: [])
        }

        if !isDirectory.boolValue {
            return DirectorySizeResult(sizeBytes: allocatedSizeForFile(at: url), issues: [])
        }

        var total: Int64 = 0
        var issues: [ScanIssue] = []
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { url, error in
                if issues.count < 20 {
                    issues.append(ScanIssue(path: url.path, message: "Skipped: \(error.localizedDescription)"))
                }
                return true
            }
        ) else {
            return DirectorySizeResult(
                sizeBytes: 0,
                issues: [ScanIssue(path: url.path, message: "Unable to enumerate this folder.")]
            )
        }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true { continue }
            if values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }

        return DirectorySizeResult(sizeBytes: total, issues: issues)
    }

    private static func allocatedSizeForFile(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else {
            return 0
        }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}

private extension URL {
    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

private extension Int {
    var megabytes: Int64 { Int64(self) * 1_024 * 1_024 }
}

private extension Array where Element == StorageFinding {
    func withoutNestedDuplicates() -> [StorageFinding] {
        var selected: [StorageFinding] = []

        for finding in sorted(by: { lhs, rhs in
            lhs.path.split(separator: "/").count > rhs.path.split(separator: "/").count
        }) {
            let path = finding.url.standardizedFileURL.path
            let isParentOfExisting = selected.contains { existing in
                existing.url.standardizedFileURL.path.hasPrefix(path + "/")
            }
            if !isParentOfExisting && !selected.contains(where: { $0.path == path }) {
                selected.append(finding)
            }
        }

        return selected
    }
}
