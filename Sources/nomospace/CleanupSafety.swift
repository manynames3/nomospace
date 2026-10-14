import AppKit
import Foundation

/// Fail-closed validation for all user-initiated moves to Trash.
/// Risk labels are guidance; they are never authorization to bypass these checks.
enum CleanupSafety {
    private static let protectedPrefixes = [
        ".ssh", ".gnupg", ".aws", ".kube", ".docker", ".orbstack",
        "Library/Keychains", "Library/Mail", "Library/Messages",
        "Library/Calendars", "Library/Accounts", "Library/Safari",
        "Library/Containers", "Library/Group Containers",
        "Library/Application Support/Google",
        "Library/Application Support/Firefox",
        "Library/Application Support/BraveSoftware",
        "Library/Application Support/Microsoft Edge",
        "Library/Application Support/Claude",
        "Library/Application Support/ChatGPT",
        "Library/Application Support/Codex",
        "Library/Application Support/com.apple.TCC",
        "Library/Application Support/Steam",
        "Library/Developer/CoreSimulator",
        "Library/Mobile Documents"
    ]

    static func refusalReason(
        for finding: StorageFinding,
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        checkProcesses: Bool = false
    ) -> String? {
        if finding.risk == .protected {
            return "This item is protected and is available for inspection only."
        }
        if finding.scanIncomplete {
            return "This folder was only partially scanned. Grant access and scan again."
        }
        return refusalReason(for: finding.url, homeURL: homeURL, checkProcesses: checkProcesses)
    }

    static func refusalReason(
        for url: URL,
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        checkProcesses: Bool = false
    ) -> String? {
        guard url.isFileURL else { return "Only local files can be moved to Trash." }
        let raw = url.path
        guard raw.hasPrefix("/"), !raw.contains("\0"),
              !raw.split(separator: "/").contains("..") else {
            return "Invalid or relative cleanup path."
        }

        let home = homeURL.standardizedFileURL.path
        let target = url.standardizedFileURL.path
        guard target.hasPrefix(home + "/") else {
            return "Cleanup outside the current user's home folder is not allowed."
        }
        let relative = String(target.dropFirst(home.count + 1))
        guard !relative.isEmpty else { return "The home directory cannot be cleaned." }
        if ["Library", "Library/Caches", "Library/Application Support",
            "Library/Developer", "Downloads"].contains(relative) {
            return "Top-level storage folders must not be moved wholesale."
        }
        // Application Support usually contains irreplaceable user state.
        // One narrowly-scoped, rebuildable wallpaper video cache is permitted.
        if relative.hasPrefix("Library/Application Support/"),
           !relative.hasPrefix("Library/Application Support/com.apple.wallpaper/aerials/videos") {
            return "Application Support contains app state. Inspect it without removing the folder."
        }

        let blocked = ["Desktop", "Documents", "Pictures", "Movies", "Music"]
        if blocked.contains(relative.components(separatedBy: "/")[0]) {
            return "Personal folders are inspection-only."
        }
        if protectedPrefixes.contains(where: {
            relative == $0 || relative.hasPrefix($0 + "/")
        }) {
            return "This path may contain protected credentials, user data, or application state."
        }

        // Reject symlinks at ANY level, including symlinked parent directories.
        // The home root itself may have a system-provided alias (/var -> /private/var).
        // Only disallow symlinks INSIDE the user's home.
        var current = homeURL.resolvingSymlinksInPath()
        for part in relative.split(separator: "/") {
            current.appendPathComponent(String(part))
            if let type = try? FileManager.default.attributesOfItem(atPath: current.path)[.type],
               let kind = type as? FileAttributeType, kind == .typeSymbolicLink {
                return "Symlinked cleanup paths are not allowed."
            }
        }
        let canonicalTarget = URL(fileURLWithPath: target).resolvingSymlinksInPath().path
        let expectedTarget = current.path
        if canonicalTarget != expectedTarget {
            return "The cleanup target resolves through a symlink."
        }
        guard FileManager.default.fileExists(atPath: target) else {
            return "This item has moved or no longer exists. Scan again."
        }

        guard checkProcesses else { return nil }

        // A running application may hold an active database or cache.
        // Prefix matching is intentionally conservative; a false positive delays
        // cleanup but does not destroy an active app's state.
        let lower = relative.lowercased()
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier?.lowercased() else { continue }
            let name = app.localizedName?.lowercased() ?? ""
            if (id.contains("adobe") && lower.contains("adobe"))
                || (id.contains("lightroom") && lower.contains("lightroom"))
                || (id.contains("aftershoot") && lower.contains("aftershoot"))
                || (id.contains("xcode") && lower.contains("xcode"))
                || (id.contains("claude") && lower.contains("claude"))
                || (id.contains("google.chrome") && lower.contains("google"))
                || (id.contains("docker") && lower.contains("docker"))
                || (id.contains("orbstack") && lower.contains("orbstack"))
                || (name == "steam" && lower.contains("steam")) {
                return "A related application is running. Quit it and scan again."
            }
            // Reverse-domain cache directory for a currently running app.
            if lower.hasPrefix("library/caches/"),
               lower.contains(id), id.count > 5 {
                return "The application that owns this cache is currently running."
            }
        }
        if let issue = openFileProbe(at: target) { return issue }
        return nil
    }

    private static func openFileProbe(at path: String) -> String? {
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        probe.arguments = ["-w", "+D", path]
        let output = Pipe()
        probe.standardOutput = output
        probe.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        probe.terminationHandler = { _ in finished.signal() }
        do {
            try probe.run()
        } catch {
            return "Unable to verify whether this folder is in use."
        }
        if finished.wait(timeout: .now() + 3) == .timedOut {
            probe.terminate()
            return "The in-use check timed out. Nothing was moved."
        }
        // macOS lsof +D can return exit code 1 even when it lists open files,
        // so the output rows, not only exit status, determine liveness.
        let lines = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).split(separator: "\n")
        if lines.dropFirst().contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            || (probe.terminationStatus == 0 && lines.count > 0) {
            return "Open files were detected here. Quit related apps before cleaning."
        }
        if probe.terminationStatus != 1 {
            return "Could not confirm this item is unused."
        }
        return nil
    }
}
