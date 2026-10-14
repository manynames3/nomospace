import Foundation

struct FolderDetail: Identifiable, Sendable {
    let url: URL
    let sizeBytes: Int64
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

struct FolderBreakdown: Sendable {
    let children: [FolderDetail]
    let totalChildren: Int
    let inspectedChildren: Int
    let skippedCount: Int
}

/// On-demand inspection of a selected finding. Read only; never deletes content.
/// Sizes are estimates, especially for APFS clones and partially accessible paths.
enum FolderInspector {
    static func inspect(_ folder: URL, inspectionLimit: Int = 120) async -> FolderBreakdown {
        await Task.detached(priority: .userInitiated) {
            let manager = FileManager.default
            let children: [URL]
            do {
                children = try manager.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: [.isSymbolicLinkKey],
                    options: []
                ).sorted { $0.lastPathComponent < $1.lastPathComponent }
            } catch {
                return FolderBreakdown(children: [], totalChildren: 0,
                                       inspectedChildren: 0, skippedCount: 1)
            }

            var details: [FolderDetail] = []
            var skipped = 0
            let candidates = Array(children.prefix(max(0, inspectionLimit)))
            for url in candidates {
                guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
                      values.isSymbolicLink != true else {
                    skipped += 1
                    continue
                }
                let result = DirectorySizer.allocatedSize(at: url)
                if !result.issues.isEmpty { skipped += 1 }
                details.append(FolderDetail(url: url, sizeBytes: result.sizeBytes))
            }
            details.sort { $0.sizeBytes > $1.sizeBytes }
            return FolderBreakdown(
                children: Array(details.prefix(20)),
                totalChildren: children.count,
                inspectedChildren: candidates.count,
                skippedCount: skipped
            )
        }.value
    }
}
