import Cocoa

func drawAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size / 1024.0
    ctx.saveGState()

    // 1. macOS squircle background with rich gradient
    let bgPadding = 80.0 * s
    let bgRect = NSRect(x: bgPadding, y: bgPadding, width: size - bgPadding * 2, height: size - bgPadding * 2)
    let cornerRadius = 195.0 * s
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

    ctx.saveGState()
    bgPath.addClip()
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.28, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.14, green: 0.34, blue: 0.72, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.06, green: 0.62, blue: 0.88, alpha: 1.0).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.55, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: locations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: bgRect.minX, y: bgRect.minY),
            end: CGPoint(x: bgRect.maxX, y: bgRect.maxY),
            options: []
        )
    }
    ctx.restoreGState()

    // Subtle inner border on squircle
    NSColor.white.withAlphaComponent(0.25).setStroke()
    bgPath.lineWidth = 6.0 * s
    bgPath.stroke()

    // 2. Main Application Window card (bottom portion)
    let winRect = NSRect(x: 175.0 * s, y: 175.0 * s, width: 674.0 * s, height: 470.0 * s)
    let winPath = NSBezierPath(roundedRect: winRect, xRadius: 36.0 * s, yRadius: 36.0 * s)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14.0 * s), blur: 28.0 * s, color: NSColor.black.withAlphaComponent(0.42).cgColor)
    NSColor(calibratedRed: 0.11, green: 0.14, blue: 0.22, alpha: 0.96).setFill()
    winPath.fill()
    ctx.restoreGState()

    NSColor.white.withAlphaComponent(0.18).setStroke()
    winPath.lineWidth = 4.0 * s
    winPath.stroke()

    // Window Traffic Light dots (Red, Yellow, Green)
    let dotY = winRect.maxY - 46.0 * s
    let dotRadius = 12.0 * s
    let trafficColors: [(CGFloat, NSColor)] = [
        (winRect.minX + 42.0 * s, NSColor(calibratedRed: 1.0, green: 0.37, blue: 0.34, alpha: 1.0)),
        (winRect.minX + 80.0 * s, NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.18, alpha: 1.0)),
        (winRect.minX + 118.0 * s, NSColor(calibratedRed: 0.15, green: 0.78, blue: 0.25, alpha: 1.0))
    ]
    for (cx, col) in trafficColors {
        let dotRect = NSRect(x: cx - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
        col.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    // Window interior content lines
    let contentLine1 = NSRect(x: winRect.minX + 44.0 * s, y: winRect.maxY - 140.0 * s, width: 360.0 * s, height: 22.0 * s)
    NSColor.white.withAlphaComponent(0.16).setFill()
    NSBezierPath(roundedRect: contentLine1, xRadius: 11.0 * s, yRadius: 11.0 * s).fill()

    let contentLine2 = NSRect(x: winRect.minX + 44.0 * s, y: winRect.maxY - 190.0 * s, width: 510.0 * s, height: 18.0 * s)
    NSColor.white.withAlphaComponent(0.10).setFill()
    NSBezierPath(roundedRect: contentLine2, xRadius: 9.0 * s, yRadius: 9.0 * s).fill()

    let contentBox = NSRect(x: winRect.minX + 44.0 * s, y: winRect.minY + 44.0 * s, width: 586.0 * s, height: 185.0 * s)
    NSColor.white.withAlphaComponent(0.06).setFill()
    NSBezierPath(roundedRect: contentBox, xRadius: 20.0 * s, yRadius: 20.0 * s).fill()

    // 3. Attached Floating Menu Bar (directly above the window!)
    let menuBarRect = NSRect(x: 175.0 * s, y: 678.0 * s, width: 560.0 * s, height: 96.0 * s)
    let menuBarPath = NSBezierPath(roundedRect: menuBarRect, xRadius: 28.0 * s, yRadius: 28.0 * s)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10.0 * s), blur: 22.0 * s, color: NSColor.black.withAlphaComponent(0.38).cgColor)
    NSColor(calibratedWhite: 0.98, alpha: 0.96).setFill()
    menuBarPath.fill()
    ctx.restoreGState()

    // Menu Bar pills representing "App  File  Edit  View"
    let pillY = menuBarRect.minY + 28.0 * s
    let pillHeight = 40.0 * s

    // Highlighted active menu pill (Blue accent)
    let activePill = NSRect(x: menuBarRect.minX + 26.0 * s, y: pillY, width: 115.0 * s, height: pillHeight)
    NSColor(calibratedRed: 0.08, green: 0.48, blue: 0.96, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: activePill, xRadius: 14.0 * s, yRadius: 14.0 * s).fill()

    // Other menu item pills
    let pill2 = NSRect(x: menuBarRect.minX + 165.0 * s, y: pillY + 6.0 * s, width: 92.0 * s, height: 28.0 * s)
    NSColor(calibratedRed: 0.15, green: 0.20, blue: 0.32, alpha: 0.70).setFill()
    NSBezierPath(roundedRect: pill2, xRadius: 12.0 * s, yRadius: 12.0 * s).fill()

    let pill3 = NSRect(x: menuBarRect.minX + 280.0 * s, y: pillY + 6.0 * s, width: 92.0 * s, height: 28.0 * s)
    NSColor(calibratedRed: 0.15, green: 0.20, blue: 0.32, alpha: 0.45).setFill()
    NSBezierPath(roundedRect: pill3, xRadius: 12.0 * s, yRadius: 12.0 * s).fill()

    let pill4 = NSRect(x: menuBarRect.minX + 395.0 * s, y: pillY + 6.0 * s, width: 110.0 * s, height: 28.0 * s)
    NSColor(calibratedRed: 0.15, green: 0.20, blue: 0.32, alpha: 0.30).setFill()
    NSBezierPath(roundedRect: pill4, xRadius: 12.0 * s, yRadius: 12.0 * s).fill()

    ctx.restoreGState()
    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String, pixelSize: Int) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return }

    rep.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rendered = drawAppIcon(size: CGFloat(pixelSize))
    rendered.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()

    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

let fm = FileManager.default
let iconsetDir = "AppIcon.iconset"
try? fm.removeItem(atPath: iconsetDir)
try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
try? fm.createDirectory(atPath: "Assets", withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
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

for (name, px) in sizes {
    savePNG(NSImage(), to: "\(iconsetDir)/\(name)", pixelSize: px)
}

// Save 512px preview for README and 128px for PrefPane
savePNG(NSImage(), to: "Assets/AppIcon-512.png", pixelSize: 512)
savePNG(NSImage(), to: "Assets/AppIcon-128.png", pixelSize: 128)
print("✅ Iconset and PNG assets generated.")
