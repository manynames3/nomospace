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
        preview.activeFilter = .developer
        try exportScreen(
            to: destination.appendingPathComponent("nomospace-audit.png"),
            viewModel: preview, section: .audit, showTop: true
        )
        preview.activeFilter = .all
        try exportScreen(
            to: destination.appendingPathComponent("nomospace-findings.png"),
            viewModel: preview, section: .guide, showTop: true
        )
    }

    private static func exportScreen(
        to url: URL,
        viewModel: AuditViewModel,
        section: AppSection,
        showTop: Bool
    ) throws {
        let width: CGFloat = 1280
        let height: CGFloat = 1120
        let display = NativePreviewLayout(viewModel: viewModel, section: section)
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
        // AppKit hosting supplies NavigationSplitView with a real NSWindow
        // environment. ImageRenderer alone produces a placeholder for this
        // window-dependent native navigation component on macOS.
        let host = NSHostingView(rootView: display)
        host.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .resizable, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.setContentSize(NSSize(width: width, height: height))
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        RunLoop.main.run(until: Date().addingTimeInterval(1.25))
        host.layoutSubtreeIfNeeded()

        // Native ScrollView's initial scroll offset is undefined while an
        // offscreen window is becoming key. Explicitly position it so the
        // overview and guide start at the top of the visible content.
        func scrollViews(in node: NSView) -> [NSScrollView] {
            (node as? NSScrollView).map { [$0] } ?? []
                + node.subviews.flatMap { scrollViews(in: $0) }
        }
        let scrollers = scrollViews(in: host)
        print("Scroll views for \(section): \(scrollers.count)")
        for scroller in scrollers {
            guard let doc = scroller.documentView else { continue }
            let top = doc.isFlipped
                ? CGFloat(0)
                : max(0, doc.bounds.height - scroller.contentView.bounds.height)
            let bottom = doc.isFlipped
                ? max(0, doc.bounds.height - scroller.contentView.bounds.height)
                : CGFloat(0)
            scroller.contentView.scroll(to: CGPoint(x: 0, y: showTop ? top : bottom))
            scroller.reflectScrolledClipView(scroller.contentView)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))

        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw Failure.emptyImage
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw Failure.invalidRepresentation
        }
        window.orderOut(nil)
        try png.write(to: url)
        print("Exported \(url.path), \(png.count) bytes")
    }
}
#endif
