import Foundation

@main
enum CleanupSafetyTests {
    static func main() async throws {
        let manager = FileManager.default
        let home = manager.temporaryDirectory
            .appendingPathComponent("nomospace-safety-tests-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: home) }

        func create(_ relative: String) throws -> URL {
            let url = home.appendingPathComponent(relative)
            try manager.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        func expectDenied(_ url: URL, _ reason: String) {
            precondition(CleanupSafety.refusalReason(for: url, homeURL: home) != nil, reason)
        }
        func expectAllowed(_ url: URL, _ reason: String) {
            precondition(CleanupSafety.refusalReason(for: url, homeURL: home) == nil, reason)
        }

        let plainCache = try create("Library/Caches/org.example.rebuildable")
        expectAllowed(plainCache, "Ordinary nested cache directory should be structurally eligible.")
        expectDenied(home, "Entire home directory must never be removed.")
        expectDenied(try create("Downloads"), "Top-level Downloads cannot be removed.")
        expectDenied(try create("Library/Keychains"), "Keychains must remain protected.")
        expectDenied(try create("Library/Application Support/Claude/vm_bundles"), "Claude state must be protected.")
        expectDenied(try create("Library/Application Support/OtherApp"), "Unknown app state must be protected.")
        expectDenied(try create("Library/Group Containers/group.example"), "App group data must be protected.")
        expectDenied(try create("Documents"), "Personal documents must be protected.")
        let outside = manager.temporaryDirectory
        expectDenied(outside, "Paths outside the scoped home must be rejected.")
        let missing = home.appendingPathComponent("Library/Caches/not-there")
        expectDenied(missing, "Missing paths must be rejected.")

        let link = home.appendingPathComponent("Library/Caches/linked")
        try manager.createSymbolicLink(at: link, withDestinationURL: home.appendingPathComponent("Documents"))
        expectDenied(link, "Symlink leaves must be blocked.")
        expectDenied(link.appendingPathComponent("anything"), "Symlink ancestors must be blocked.")

        let protected = StorageFinding(
            id: plainCache.path, title: "Protected", sizeBytes: 10,
            url: plainCache, category: .cache, risk: .protected,
            explanation: "", sideEffect: "", source: ""
        )
        precondition(CleanupSafety.refusalReason(for: protected, homeURL: home) != nil,
                     "A protected finding must never be moved.")
        var incomplete = protected
        incomplete.scanIncomplete = true
        precondition(CleanupSafety.refusalReason(for: incomplete, homeURL: home) != nil,
                     "Incomplete scans may not authorize removal.")

        let inspectRoot = try create("Library/Caches/inspect-test")
        let large = inspectRoot.appendingPathComponent("larger.bin")
        let small = inspectRoot.appendingPathComponent("smaller.bin")
        try Data(repeating: 1, count: 64_000).write(to: large)
        try Data(repeating: 2, count: 8_000).write(to: small)
        let breakdown = await FolderInspector.inspect(inspectRoot)
        precondition(breakdown.totalChildren == 2 && breakdown.children.count == 2,
                     "Folder inspector must list actual children.")
        precondition(breakdown.children.first?.name == "larger.bin",
                     "Folder inspector must sort by estimated allocated size.")

        // Verify the real lsof-based guard blocks a directory with an open file.
        let openFile = try FileHandle(forReadingFrom: large)
        precondition(CleanupSafety.refusalReason(
            for: inspectRoot, homeURL: home, checkProcesses: true
        ) != nil, "Open files must prevent cleanup.")
        try openFile.close()
        precondition(CleanupSafety.refusalReason(
            for: inspectRoot, homeURL: home, checkProcesses: true
        ) == nil, "Idle rebuildable folders should remain selectable.")

        print("CleanupSafetyTests passed: protection, symlinks, boundaries, and folder inspection")
    }
}
