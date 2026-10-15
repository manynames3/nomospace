import AppKit
import Foundation

// Deterministic app icon renderer. All marketing and Dock icons originate from
// branding/nomospace-glass.svg and its checked-in 1024px master raster.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("branding/nomospace-glass.png")
let iconset = root.appendingPathComponent("Packaging/nomospace.iconset")
let output = root.appendingPathComponent("Packaging/nomospace.icns")
guard let source = NSImage(contentsOf: sourceURL), source.isValid else {
    fatalError("Missing master brand artwork at \(sourceURL.path)")
}
let manager = FileManager.default
try? manager.removeItem(at: iconset)
try manager.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? manager.removeItem(at: iconset) }

let dimensions: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"), (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"), (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"), (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]
for (size, name) in dimensions {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Failed to allocate icon \(name)")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    source.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(origin: .zero, size: source.size),
        operation: .sourceOver, fraction: 1
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode icon \(name)")
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}
print("Generated \(output.path) from the approved glass-layer artwork.")
