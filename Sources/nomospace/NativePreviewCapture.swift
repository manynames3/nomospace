#if DEBUG
import AppKit
import SwiftUI

/// Generates sample-data previews by rendering the SAME SwiftUI views as the app.
/// No real user storage is scanned; every exported image is labeled SAMPLE DATA.
@MainActor
enum NativePreviewCapture {
    enum Failure: Error { case invalidArguments, emptyImage, invalidRepresentation }

    static func export(arguments: [String]) throws {
        guard let option = arguments.firstIndex(of: "--export-preview"),
              arguments.indices.contains(option + 1) else {
            throw Failure.invalidArguments
        }

        let destination = URL(fileURLWithPath: arguments[option + 1], isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        _ = NSApplication.shared

        let preview = AuditViewModel()
        preview.loadPreviewFixtures()
        try exportScreen(
            to: destination.appendingPathComponent("nomospace-audit.png"),
            viewModel: preview, section: .audit
        )
        try exportScreen(
            to: destination.appendingPathComponent("nomospace-safety.png"),
            viewModel: preview, section: .guide
        )
    }

    private static func exportScreen(
        to url: URL,
        viewModel: AuditViewModel,
        section: AppSection
    ) throws {
        let width: CGFloat = 1280
        let height: CGFloat = 900
        let display = ContentView(viewModel: viewModel, section: section, previewMode: true)
            .frame(width: width, height: height)
            .environment(\.colorScheme, .light)
            .overlay(alignment: .topTrailing) {
                Text("SAMPLE DATA  ·  UI PREVIEW")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.mint, in: Capsule())
                    .padding(.top, 8)
                    .padding(.trailing, 14)
            }
        let renderer = ImageRenderer(content: display)
        renderer.scale = 1.5
        guard let image = renderer.nsImage,
              image.size.width > 1000,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw Failure.emptyImage
        }
        try png.write(to: url)
        print("Exported \(url.path), \(png.count) bytes")
    }
}
#endif
