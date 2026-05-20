import Foundation

struct StorageScanner: Sendable {
    func scan() async -> [StorageFinding] {
        let known = knownCandidates()

        return await Task.detached(priority: .userInitiated) {
            var findings: [StorageFinding] = []
            var knownExistingPaths: Set<String> = []

            for candidate in known {
                guard candidate.url.exists else { continue }
                let size = DirectorySizer.allocatedSize(at: candidate.url)
                guard size >= candidate.minimumBytes else { continue }
                knownExistingPaths.insert(candidate.url.standardizedFileURL.path)
                findings.append(candidate.finding(sizeBytes: size))
            }

            findings.append(contentsOf: scanLargeChildren(
                parent: Self.home.appendingPathComponent("Library/Application Support"),
                category: .appData,
                risk: .review,
                minimumBytes: 750.megabytes,
                source: "Application Support",
                knownSpecificPaths: knownExistingPaths
            ))

            findings.append(contentsOf: scanLargeChildren(
                parent: Self.home.appendingPathComponent("Library/Caches"),
                category: .cache,
                risk: .safe,
                minimumBytes: 250.megabytes,
                source: "User Cache",
                knownSpecificPaths: knownExistingPaths
            ))

            findings.append(contentsOf: scanPersonalFolders(knownSpecificPaths: knownExistingPaths))

            return findings
                .uniqueByPath()
                .sorted { lhs, rhs in
                    if lhs.sizeBytes == rhs.sizeBytes {
                        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                    }
                    return lhs.sizeBytes > rhs.sizeBytes
                }
        }.value
    }

    private static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    private func knownCandidates() -> [KnownCandidate] {
        let home = Self.home

        return [
            KnownCandidate(
                title: "Apple Aerial Wallpaper Videos",
                relativePath: "Library/Application Support/com.apple.wallpaper/aerials/videos",
                category: .appleSystem,
                risk: .usuallySafe,
                explanation: "Downloaded aerial wallpaper and screensaver videos. macOS can recreate this folder if the feature is used again.",
                sideEffect: "Wallpaper or screensaver choices may reset, and macOS may redownload videos later.",
                source: "Apple Wallpaper",
                minimumBytes: 250.megabytes
            ),
            KnownCandidate(
                title: "Adobe Camera Raw Cache",
                relativePath: "Library/Caches/Adobe Camera Raw 2",
                category: .adobePhoto,
                risk: .safe,
                explanation: "Adobe Camera Raw stores preview and processing cache files here.",
                sideEffect: "Adobe apps may rebuild previews and feel slower for the first few opens.",
                source: "Adobe",
                minimumBytes: 250.megabytes
            ),
            KnownCandidate(
                title: "Lightroom Classic Cache",
                relativePath: "Library/Caches/com.adobe.LightroomClassicCC7",
                category: .adobePhoto,
                risk: .usuallySafe,
                explanation: "Lightroom Classic cache data used to speed up image browsing and editing.",
                sideEffect: "Lightroom may regenerate previews and cached data.",
                source: "Adobe Lightroom",
                minimumBytes: 250.megabytes
            ),
            KnownCandidate(
                title: "Xcode Derived Data",
                relativePath: "Library/Developer/Xcode/DerivedData",
                category: .developer,
                risk: .safe,
                explanation: "Xcode build products, indexes, and intermediate files.",
                sideEffect: "Xcode will rebuild project indexes and derived build output later.",
                source: "Xcode",
                minimumBytes: 250.megabytes
            ),
            KnownCandidate(
                title: "Xcode iOS Device Support",
                relativePath: "Library/Developer/Xcode/iOS DeviceSupport",
                category: .developer,
                risk: .usuallySafe,
                explanation: "Device symbols and support files Xcode stores after connecting iPhones or iPads.",
                sideEffect: "Xcode may recreate support files when devices are connected again.",
                source: "Xcode",
                minimumBytes: 500.megabytes
            ),
            KnownCandidate(
                title: "User Simulator Devices",
                relativePath: "Library/Developer/CoreSimulator",
                category: .developer,
                risk: .usuallySafe,
                explanation: "Local iOS simulator devices, apps, and runtime data.",
                sideEffect: "Simulator devices and their installed test apps may be removed.",
                source: "CoreSimulator",
                minimumBytes: 500.megabytes
            ),
            KnownCandidate(
                title: "npm Download Cache",
                relativePath: ".npm/_cacache",
                category: .developer,
                risk: .safe,
                explanation: "npm package tarballs and metadata used to speed up installs.",
                sideEffect: "Future npm installs may be slower while packages redownload.",
                source: "npm",
                minimumBytes: 250.megabytes
            ),
            KnownCandidate(
                title: "npx Temporary Packages",
                relativePath: ".npm/_npx",
                category: .developer,
                risk: .safe,
                explanation: "Temporary packages downloaded by npx commands.",
                sideEffect: "npx may redownload tools the next time they are used.",
                source: "npm",
                minimumBytes: 250.megabytes
            ),
            KnownCandidate(
                title: "Claude VM Bundles",
                relativePath: "Library/Application Support/Claude/vm_bundles",
                category: .appData,
                risk: .usuallySafe,
                explanation: "Claude desktop runtime bundles and virtual machine assets.",
                sideEffect: "Claude may redownload runtime components the next time local features are used.",
                source: "Claude",
                minimumBytes: 500.megabytes
            ),
            KnownCandidate(
                title: "Google Browser Profile Data",
                relativePath: "Library/Application Support/Google",
                category: .browser,
                risk: .review,
                explanation: "Chrome and Google app profiles, site storage, extensions, and account data.",
                sideEffect: "Removing this can affect browser profiles, extensions, login state, and local web app data.",
                source: "Google",
                minimumBytes: 1.gigabytes
            )
        ].map { $0.resolved(relativeTo: home) }
    }
}

private struct KnownCandidate: Sendable {
    let title: String
    let relativePath: String
    let category: FindingCategory
    let risk: RiskLevel
    let explanation: String
    let sideEffect: String
    let source: String
    let minimumBytes: Int64
    private(set) var url: URL = FileManager.default.homeDirectoryForCurrentUser

    func resolved(relativeTo baseURL: URL) -> KnownCandidate {
        var copy = self
        copy.url = baseURL.appendingPathComponent(relativePath)
        return copy
    }

    func finding(sizeBytes: Int64) -> StorageFinding {
        StorageFinding(
            id: url.standardizedFileURL.path,
            title: title,
            sizeBytes: sizeBytes,
            url: url,
            category: category,
            risk: risk,
            explanation: explanation,
            sideEffect: sideEffect,
            source: source
        )
    }
}

private func scanLargeChildren(
    parent: URL,
    category: FindingCategory,
    risk: RiskLevel,
    minimumBytes: Int64,
    source: String,
    knownSpecificPaths: Set<String>
) -> [StorageFinding] {
    guard parent.exists else { return [] }

    let children = (try? FileManager.default.contentsOfDirectory(
        at: parent,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )) ?? []

    return children.compactMap { child in
        let standardizedPath = child.standardizedFileURL.path
        guard !knownSpecificPaths.contains(standardizedPath) else { return nil }
        guard !knownSpecificPaths.contains(where: { knownPath in
            knownPath.hasPrefix(standardizedPath + "/")
        }) else { return nil }

        let size = DirectorySizer.allocatedSize(at: child)
        guard size >= minimumBytes else { return nil }

        return StorageFinding(
            id: standardizedPath,
            title: child.lastPathComponent,
            sizeBytes: size,
            url: child,
            category: category,
            risk: risk,
            explanation: "Large storage under \(source). This may be cache, app state, local content, or downloaded resources.",
            sideEffect: risk == .safe
                ? "The app may rebuild these files later."
                : "Review this path before selecting it. It may contain app state or local user data.",
            source: source
        )
    }
}

private func scanPersonalFolders(knownSpecificPaths: Set<String>) -> [StorageFinding] {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let folders: [(String, FindingCategory, RiskLevel, String)] = [
        ("Desktop", .personal, .protected, "Desktop files are usually personal or active work."),
        ("Downloads", .personal, .review, "Downloads may contain installers, exports, documents, and media."),
        ("Documents", .personal, .protected, "Documents usually contains personal or project files."),
        ("Pictures", .media, .protected, "Pictures may contain photo libraries or personal media."),
        ("Movies", .media, .protected, "Movies may contain personal media and exports."),
        ("Aftershoot Projects", .media, .protected, "Aftershoot projects may contain active photo work.")
    ]

    return folders.compactMap { name, category, risk, explanation in
        let url = home.appendingPathComponent(name)
        let standardizedPath = url.standardizedFileURL.path
        guard url.exists else { return nil }
        guard !knownSpecificPaths.contains(standardizedPath) else { return nil }

        let size = DirectorySizer.allocatedSize(at: url)
        guard size >= 500.megabytes else { return nil }

        return StorageFinding(
            id: standardizedPath,
            title: name,
            sizeBytes: size,
            url: url,
            category: category,
            risk: risk,
            explanation: explanation,
            sideEffect: "Use Reveal in Finder and decide manually. nomospace does not auto-select personal folders.",
            source: "Home Folder"
        )
    }
}

private enum DirectorySizer {
    static func allocatedSize(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            return allocatedSizeForFile(at: url)
        }

        var total: Int64 = 0
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
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true { continue }
            if values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }

        return total
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
    var gigabytes: Int64 { Int64(self) * 1_024 * 1_024 * 1_024 }
}

private extension Array where Element == StorageFinding {
    func uniqueByPath() -> [StorageFinding] {
        var seen = Set<String>()
        return filter { finding in
            let path = finding.url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }
}
