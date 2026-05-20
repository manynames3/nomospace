import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsURL = rootURL
    .appendingPathComponent("landing", isDirectory: true)
    .appendingPathComponent("assets", isDirectory: true)

try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)

try renderIcon(size: 512).pngData().write(to: assetsURL.appendingPathComponent("nomospace-icon.png"))
try renderHeroPreview(width: 1800, height: 1120).pngData().write(to: assetsURL.appendingPathComponent("nomospace-hero-preview.png"))
try renderReportPreview(width: 1200, height: 840).pngData().write(to: assetsURL.appendingPathComponent("nomospace-report-preview.png"))

print(assetsURL.path)

private func renderIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let background = NSBezierPath(
        roundedRect: rect.insetBy(dx: CGFloat(size) * 0.04, dy: CGFloat(size) * 0.04),
        xRadius: CGFloat(size) * 0.22,
        yRadius: CGFloat(size) * 0.22
    )
    NSGradient(colors: [
        NSColor(calibratedRed: 0.06, green: 0.22, blue: 0.58, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.48, blue: 0.43, alpha: 1)
    ])?.draw(in: background, angle: 135)

    drawText("n", in: NSRect(x: 0, y: CGFloat(size) * 0.1, width: CGFloat(size), height: CGFloat(size) * 0.75), size: CGFloat(size) * 0.44, weight: .semibold, color: .white, alignment: .center)

    image.unlockFocus()
    return image
}

private func renderHeroPreview(width: Int, height: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    drawBackground(width: width, height: height)

    let window = NSRect(x: 650, y: 150, width: 1080, height: 790)
    drawWindow(rect: window, title: "nomospace")
    drawSidebar(in: window)
    drawDashboard(in: window)

    image.unlockFocus()
    return image
}

private func renderReportPreview(width: Int, height: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()

    NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.98, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    let window = NSRect(x: 52, y: 52, width: width - 104, height: height - 104)
    drawWindow(rect: window, title: "nomospace audit report")
    drawText("Storage Audit Report", in: NSRect(x: 104, y: 710, width: 520, height: 40), size: 30, weight: .semibold, color: ink)
    drawText("Generated locally. No uploads. 17 cleanup rules loaded.", in: NSRect(x: 104, y: 675, width: 600, height: 28), size: 17, weight: .regular, color: muted)

    let cards = [
        ("Reclaimable", "64.2 GB", blue),
        ("Safe", "15.8 GB", green),
        ("Review", "48.4 GB", amber)
    ]
    for (index, card) in cards.enumerated() {
        drawMetric(title: card.0, value: card.1, rect: NSRect(x: 104 + index * 320, y: 550, width: 280, height: 100), accent: card.2)
    }

    let rows = [
        ("Apple Aerial Wallpaper Videos", "48 GB", "Review"),
        ("Adobe Camera Raw Cache", "9 GB", "Safe"),
        ("Xcode Derived Data", "4.5 GB", "Usually Safe"),
        ("npm download cache", "1.4 GB", "Safe")
    ]
    for (index, row) in rows.enumerated() {
        drawFindingRow(title: row.0, size: row.1, risk: row.2, y: 430 - CGFloat(index) * 74, width: 990)
    }

    image.unlockFocus()
    return image
}

private func drawBackground(width: Int, height: Int) {
    let rect = NSRect(x: 0, y: 0, width: width, height: height)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.06, green: 0.12, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.35, blue: 0.42, alpha: 1),
        NSColor(calibratedRed: 0.88, green: 0.92, blue: 0.89, alpha: 1)
    ])?.draw(in: rect, angle: 22)
}

private func drawWindow(rect: NSRect, title: String) {
    shadow()
    let path = NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24)
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let toolbar = NSRect(x: rect.minX, y: rect.maxY - 62, width: rect.width, height: 62)
    NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: toolbar, xRadius: 24, yRadius: 24).fill()
    drawText(title, in: NSRect(x: rect.minX + 76, y: rect.maxY - 43, width: 240, height: 24), size: 17, weight: .semibold, color: ink)
    for index in 0..<3 {
        let dot = NSRect(x: rect.minX + 24 + CGFloat(index) * 24, y: rect.maxY - 38, width: 12, height: 12)
        NSBezierPath(ovalIn: dot).fill(with: [coral, amber, green][index])
    }
}

private func drawSidebar(in window: NSRect) {
    let sidebar = NSRect(x: window.minX, y: window.minY, width: 220, height: window.height - 62)
    NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.97, alpha: 1).setFill()
    sidebar.fill()
    drawText("Audit", in: NSRect(x: sidebar.minX + 34, y: sidebar.maxY - 86, width: 120, height: 22), size: 17, weight: .semibold, color: blue)
    drawText("History", in: NSRect(x: sidebar.minX + 34, y: sidebar.maxY - 134, width: 120, height: 22), size: 16, weight: .regular, color: muted)
    drawText("Guide", in: NSRect(x: sidebar.minX + 34, y: sidebar.maxY - 178, width: 120, height: 22), size: 16, weight: .regular, color: muted)
}

private func drawDashboard(in window: NSRect) {
    let x = window.minX + 260
    let top = window.maxY - 116
    drawText("Your Mac is full. nomospace shows exactly why.", in: NSRect(x: x, y: top, width: 680, height: 40), size: 29, weight: .semibold, color: ink)
    drawText("Find hidden System Data, app caches, developer artifacts, and bloat normal cleaners miss.", in: NSRect(x: x, y: top - 36, width: 680, height: 26), size: 17, weight: .regular, color: muted)

    drawMetric(title: "Reclaimable", value: "64.2 GB", rect: NSRect(x: x, y: top - 168, width: 230, height: 105), accent: blue)
    drawMetric(title: "Safe", value: "15.8 GB", rect: NSRect(x: x + 250, y: top - 168, width: 200, height: 105), accent: green)
    drawMetric(title: "Review", value: "48.4 GB", rect: NSRect(x: x + 470, y: top - 168, width: 200, height: 105), accent: amber)

    let rows = [
        ("Apple Aerial Wallpaper Videos", "48 GB", "Review"),
        ("Adobe Camera Raw Cache", "9 GB", "Safe"),
        ("Xcode Derived Data", "4.5 GB", "Usually Safe"),
        ("npm download cache", "1.4 GB", "Safe")
    ]
    for (index, row) in rows.enumerated() {
        drawFindingRow(title: row.0, size: row.1, risk: row.2, y: top - 286 - CGFloat(index) * 82, width: 740, originX: x)
    }
}

private func drawMetric(title: String, value: String, rect: NSRect, accent: NSColor) {
    rounded(rect, radius: 14, color: NSColor.white)
    stroke(rect, radius: 14)
    drawText(value, in: NSRect(x: rect.minX + 18, y: rect.minY + 44, width: rect.width - 36, height: 36), size: 28, weight: .semibold, color: ink)
    drawText(title, in: NSRect(x: rect.minX + 18, y: rect.minY + 20, width: rect.width - 36, height: 22), size: 15, weight: .regular, color: muted)
    NSBezierPath(roundedRect: NSRect(x: rect.minX + 18, y: rect.maxY - 24, width: 32, height: 5), xRadius: 2, yRadius: 2).fill(with: accent)
}

private func drawFindingRow(title: String, size: String, risk: String, y: CGFloat, width: CGFloat, originX: CGFloat = 104) {
    let rect = NSRect(x: originX, y: y, width: width, height: 58)
    rounded(rect, radius: 12, color: NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 1))
    stroke(rect, radius: 12)
    drawText(title, in: NSRect(x: rect.minX + 18, y: rect.minY + 28, width: rect.width * 0.58, height: 22), size: 16, weight: .semibold, color: ink)
    drawText("~/Library/Application Support/...", in: NSRect(x: rect.minX + 18, y: rect.minY + 10, width: rect.width * 0.58, height: 18), size: 12, weight: .regular, color: muted)
    drawText(risk, in: NSRect(x: rect.maxX - 205, y: rect.minY + 22, width: 100, height: 22), size: 13, weight: .semibold, color: risk == "Safe" ? green : amber)
    drawText(size, in: NSRect(x: rect.maxX - 94, y: rect.minY + 21, width: 72, height: 24), size: 16, weight: .semibold, color: ink, alignment: .right)
}

private func rounded(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func stroke(_ rect: NSRect, radius: CGFloat) {
    NSColor(calibratedRed: 0.84, green: 0.88, blue: 0.92, alpha: 1).setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = 1
    path.stroke()
}

private func drawText(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    text.draw(in: rect, withAttributes: attributes)
}

private func shadow() {
    NSGraphicsContext.current?.saveGraphicsState()
    NSShadow().apply {
        $0.shadowOffset = NSSize(width: 0, height: -18)
        $0.shadowBlurRadius = 36
        $0.shadowColor = NSColor.black.withAlphaComponent(0.18)
    }
}

private let ink = NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)
private let muted = NSColor(calibratedRed: 0.36, green: 0.40, blue: 0.46, alpha: 1)
private let blue = NSColor(calibratedRed: 0.06, green: 0.31, blue: 0.60, alpha: 1)
private let green = NSColor(calibratedRed: 0.08, green: 0.47, blue: 0.30, alpha: 1)
private let amber = NSColor(calibratedRed: 0.65, green: 0.37, blue: 0.03, alpha: 1)
private let coral = NSColor(calibratedRed: 0.73, green: 0.30, blue: 0.24, alpha: 1)

private extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}

private extension NSImage {
    func pngData() -> Data {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Could not render PNG")
        }
        return data
    }
}

private extension NSShadow {
    func apply(_ configure: (NSShadow) -> Void) {
        configure(self)
        set()
    }
}
