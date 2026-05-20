import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let packagingURL = rootURL.appendingPathComponent("Packaging", isDirectory: true)
let iconsetURL = packagingURL.appendingPathComponent("nomospace.iconset", isDirectory: true)
let outputURL = packagingURL.appendingPathComponent("nomospace.icns")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconSizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, name) in iconSizes {
    let image = makeIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(name)")
    }
    try png.write(to: iconsetURL.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}

try fileManager.removeItem(at: iconsetURL)
print(outputURL.path)

private func makeIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = CGFloat(size) * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.04, dy: CGFloat(size) * 0.04), xRadius: radius, yRadius: radius)
    NSGradient(
        colors: [
            NSColor(calibratedRed: 0.06, green: 0.20, blue: 0.56, alpha: 1),
            NSColor(calibratedRed: 0.06, green: 0.48, blue: 0.62, alpha: 1)
        ]
    )?.draw(in: background, angle: 135)

    let inset = CGFloat(size) * 0.20
    let trayRect = NSRect(
        x: inset,
        y: CGFloat(size) * 0.22,
        width: CGFloat(size) - inset * 2,
        height: CGFloat(size) * 0.18
    )
    let tray = NSBezierPath(roundedRect: trayRect, xRadius: CGFloat(size) * 0.035, yRadius: CGFloat(size) * 0.035)
    NSColor.white.withAlphaComponent(0.22).setFill()
    tray.fill()

    let barWidths: [CGFloat] = [0.18, 0.30, 0.44]
    for (index, width) in barWidths.enumerated() {
        let barRect = NSRect(
            x: inset,
            y: CGFloat(size) * (0.49 + CGFloat(index) * 0.075),
            width: CGFloat(size) * width,
            height: max(2, CGFloat(size) * 0.042)
        )
        let bar = NSBezierPath(roundedRect: barRect, xRadius: CGFloat(size) * 0.02, yRadius: CGFloat(size) * 0.02)
        NSColor.white.withAlphaComponent(index == 2 ? 0.92 : 0.70).setFill()
        bar.fill()
    }

    let letter = "n" as NSString
    let font = NSFont.systemFont(ofSize: CGFloat(size) * 0.36, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let letterSize = letter.size(withAttributes: attributes)
    letter.draw(
        at: NSPoint(
            x: CGFloat(size) * 0.56,
            y: CGFloat(size) * 0.43 - letterSize.height * 0.5
        ),
        withAttributes: attributes
    )

    image.unlockFocus()
    return image
}
