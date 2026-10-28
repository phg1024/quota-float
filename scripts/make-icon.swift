// Draws the app icon (two quota bars on a dark tile) and writes Support/AppIcon.icns.
// Usage: swift scripts/make-icon.swift   (run from the repository root)
import Cocoa

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels) / 1024
    // macOS icon grid: 824 pt tile centred on a 1024 pt canvas.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: NSColor(red: 0.13, green: 0.16, blue: 0.20, alpha: 1),
               ending: NSColor(red: 0.06, green: 0.075, blue: 0.09, alpha: 1))!.draw(in: shape, angle: -90)
    NSColor(white: 1, alpha: 0.08).setStroke()
    shape.lineWidth = 4 * s
    shape.stroke()
    let bars: [(y: CGFloat, fill: CGFloat, color: NSColor)] = [
        (560, 0.72, NSColor(red: 0.39, green: 0.89, blue: 0.80, alpha: 1)),
        (340, 0.45, NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1)),
    ]
    for bar in bars {
        let track = NSRect(x: 232 * s, y: bar.y * s, width: 560 * s, height: 124 * s)
        NSColor(white: 1, alpha: 0.10).setFill()
        NSBezierPath(roundedRect: track, xRadius: 62 * s, yRadius: 62 * s).fill()
        var filled = track
        filled.size.width *= bar.fill
        bar.color.setFill()
        NSBezierPath(roundedRect: filled, xRadius: 62 * s, yRadius: 62 * s).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(pixels: points * scale).write(to: iconset.appendingPathComponent(name))
    }
}
try render(pixels: 1024).write(to: root.appendingPathComponent("docs/icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Support/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Support/AppIcon.icns and docs/icon.png" : "iconutil failed")
exit(iconutil.terminationStatus)
