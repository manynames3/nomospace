import Darwin
import SwiftUI

@main
struct NomospaceApp: App {
    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--export-preview") {
            do {
                try NativePreviewCapture.export(arguments: CommandLine.arguments)
                print("Native preview screenshots exported.")
                exit(0)
            } catch {
                fputs("Preview export failed: \(error)\n", stderr)
                exit(1)
            }
        }
        #endif
        if CommandLine.arguments.contains("--self-test") {
            let rules = StorageRule.bundledRules()
            let hasAerialRule = rules.contains { $0.id == "apple-aerial-wallpaper-videos" }

            guard rules.count >= 10, hasAerialRule else {
                fputs("nomospace self-test failed: bundled cleanup rules did not load\n", stderr)
                exit(1)
            }

            print("nomospace self-test passed: \(rules.count) rules loaded")
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1080, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
