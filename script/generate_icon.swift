import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let fileManager = FileManager.default
let rootURL = outputURL.deletingLastPathComponent()
let iconsetURL = rootURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)

try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
if fileManager.fileExists(atPath: iconsetURL.path) {
    try fileManager.removeItem(at: iconsetURL)
}
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    let image = makeIcon(size: variant.pixels)
    let destination = iconsetURL.appendingPathComponent(variant.name)
    try writePNG(image, to: destination)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(
        domain: "SleepKeeperIcon",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "iconutil failed with status \(process.terminationStatus)"]
    )
}

func makeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    let inset = size * 0.055
    let tileRect = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.205
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    shadow.shadowBlurRadius = size * 0.04
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.set()
    NSColor.black.setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    tilePath.addClip()
    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.06, green: 0.18, blue: 0.23, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.09, blue: 0.16, alpha: 1)
    ])
    background?.draw(in: tileRect, angle: -42)

    let glowRect = NSRect(
        x: size * 0.22,
        y: size * 0.17,
        width: size * 0.68,
        height: size * 0.68
    )
    NSGradient(colors: [
        NSColor(calibratedRed: 0.18, green: 0.86, blue: 0.72, alpha: 0.42),
        NSColor(calibratedRed: 0.17, green: 0.52, blue: 1, alpha: 0.04)
    ])?.draw(in: NSBezierPath(ovalIn: glowRect), relativeCenterPosition: NSPoint(x: 0.18, y: 0.16))

    drawMoon(size: size)
    drawBolt(size: size)

    NSGraphicsContext.saveGraphicsState()
    let rimPath = NSBezierPath(roundedRect: tileRect.insetBy(dx: size * 0.006, dy: size * 0.006), xRadius: cornerRadius, yRadius: cornerRadius)
    rimPath.lineWidth = max(1, size * 0.012)
    NSColor.white.withAlphaComponent(0.16).setStroke()
    rimPath.stroke()
    NSGraphicsContext.restoreGraphicsState()

    return image
}

func drawMoon(size: CGFloat) {
    let moonRect = NSRect(x: size * 0.21, y: size * 0.24, width: size * 0.43, height: size * 0.43)
    let moon = NSBezierPath(ovalIn: moonRect)
    NSColor(calibratedRed: 0.83, green: 0.93, blue: 1, alpha: 0.94).setFill()
    moon.fill()

    let cutoutRect = moonRect.offsetBy(dx: size * 0.135, dy: size * 0.07)
    let cutout = NSBezierPath(ovalIn: cutoutRect)
    NSColor(calibratedRed: 0.055, green: 0.15, blue: 0.20, alpha: 1).setFill()
    cutout.fill()
}

func drawBolt(size: CGFloat) {
    let bolt = NSBezierPath()
    bolt.move(to: NSPoint(x: size * 0.57, y: size * 0.77))
    bolt.line(to: NSPoint(x: size * 0.38, y: size * 0.50))
    bolt.line(to: NSPoint(x: size * 0.54, y: size * 0.50))
    bolt.line(to: NSPoint(x: size * 0.45, y: size * 0.24))
    bolt.line(to: NSPoint(x: size * 0.70, y: size * 0.58))
    bolt.line(to: NSPoint(x: size * 0.55, y: size * 0.58))
    bolt.close()

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
    shadow.shadowBlurRadius = size * 0.02
    shadow.shadowColor = NSColor(calibratedRed: 0.0, green: 0.95, blue: 0.70, alpha: 0.52)
    shadow.set()
    NSColor(calibratedRed: 0.42, green: 1, blue: 0.79, alpha: 1).setFill()
    bolt.fill()
    NSGraphicsContext.restoreGraphicsState()

    bolt.lineWidth = max(1, size * 0.012)
    NSColor.white.withAlphaComponent(0.58).setStroke()
    bolt.stroke()
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(
            domain: "SleepKeeperIcon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to render PNG for \(url.lastPathComponent)"]
        )
    }

    try pngData.write(to: url)
}
