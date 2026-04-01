import AppKit
import Foundation

let fileManager = FileManager.default
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Sources/SecretSyncApp/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

struct IconSpec {
    let filename: String
    let size: Int
}

let specs = [
    IconSpec(filename: "icon_16x16.png", size: 16),
    IconSpec(filename: "icon_16x16@2x.png", size: 32),
    IconSpec(filename: "icon_32x32.png", size: 32),
    IconSpec(filename: "icon_32x32@2x.png", size: 64),
    IconSpec(filename: "icon_128x128.png", size: 128),
    IconSpec(filename: "icon_128x128@2x.png", size: 256),
    IconSpec(filename: "icon_256x256.png", size: 256),
    IconSpec(filename: "icon_256x256@2x.png", size: 512),
    IconSpec(filename: "icon_512x512.png", size: 512),
    IconSpec(filename: "icon_512x512@2x.png", size: 1024)
]

try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func roundedRectPath(in rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawBackground(in rect: NSRect) {
    let outerRadius = rect.width * 0.225
    let outerRect = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04)
    let outerPath = roundedRectPath(in: outerRect, radius: outerRadius)

    NSGraphicsContext.saveGraphicsState()
    outerPath.addClip()
    NSGradient(colors: [
        color(13, 31, 64),
        color(22, 87, 150),
        color(49, 193, 176)
    ])?.draw(in: outerPath, angle: 55)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    let glowRect = outerRect.offsetBy(dx: 0, dy: outerRect.height * 0.18)
    let glowPath = NSBezierPath(ovalIn: glowRect)
    glowPath.addClip()
    NSGradient(colors: [
        color(255, 255, 255, 0.32),
        color(255, 255, 255, 0.02)
    ])?.draw(in: glowPath, relativeCenterPosition: NSPoint(x: 0, y: 0.3))
    NSGraphicsContext.restoreGraphicsState()

    color(255, 255, 255, 0.18).setStroke()
    outerPath.lineWidth = rect.width * 0.012
    outerPath.stroke()

    let innerRect = outerRect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04)
    let innerPath = roundedRectPath(in: innerRect, radius: outerRadius * 0.72)
    NSGraphicsContext.saveGraphicsState()
    innerPath.addClip()
    NSGradient(colors: [
        color(255, 255, 255, 0.10),
        color(255, 255, 255, 0.0)
    ])?.draw(in: innerPath, angle: 90)
    NSGraphicsContext.restoreGraphicsState()
}

func drawRepositoryCards(in rect: NSRect) {
    let baseY = rect.minY + rect.height * 0.2
    let cardHeight = rect.height * 0.14
    let cardWidth = rect.width * 0.58
    let x = rect.midX - cardWidth / 2
    let offsets: [CGFloat] = [rect.height * 0.18, rect.height * 0.10, rect.height * 0.02]
    let scales: [CGFloat] = [0.88, 0.94, 1.0]

    for index in 0..<offsets.count {
        let scale = scales[index]
        let width = cardWidth * scale
        let height = cardHeight * scale
        let cardRect = NSRect(
            x: rect.midX - width / 2,
            y: baseY + offsets[index],
            width: width,
            height: height
        )
        let cardPath = roundedRectPath(in: cardRect, radius: rect.width * 0.055)
        NSGraphicsContext.saveGraphicsState()
        cardPath.addClip()
        NSGradient(colors: [
            color(239, 247, 255, 0.98),
            color(199, 226, 246, 0.92)
        ])?.draw(in: cardPath, angle: 90)
        NSGraphicsContext.restoreGraphicsState()

        color(9, 44, 84, 0.10).setStroke()
        cardPath.lineWidth = rect.width * 0.007
        cardPath.stroke()

        let lineInsetX = width * 0.11
        let lineInsetY = height * 0.24
        let lineWidth = width * 0.48
        let lineHeight = height * 0.14
        let shortWidth = width * 0.28

        let topLine = roundedRectPath(
            in: NSRect(
                x: cardRect.minX + lineInsetX,
                y: cardRect.maxY - lineInsetY - lineHeight,
                width: lineWidth,
                height: lineHeight
            ),
            radius: lineHeight / 2
        )
        color(73, 138, 194, 0.60).setFill()
        topLine.fill()

        let bottomLine = roundedRectPath(
            in: NSRect(
                x: cardRect.minX + lineInsetX,
                y: cardRect.minY + lineInsetY,
                width: shortWidth,
                height: lineHeight
            ),
            radius: lineHeight / 2
        )
        color(73, 138, 194, 0.42).setFill()
        bottomLine.fill()
    }

    let accentRect = NSRect(
        x: x + cardWidth * 0.69,
        y: baseY + rect.height * 0.06,
        width: rect.width * 0.12,
        height: rect.width * 0.12
    )
    let accentPath = NSBezierPath(ovalIn: accentRect)
    color(80, 214, 194, 0.92).setFill()
    accentPath.fill()
}

func drawShield(in rect: NSRect) {
    let shieldRect = NSRect(
        x: rect.midX - rect.width * 0.19,
        y: rect.minY + rect.height * 0.29,
        width: rect.width * 0.38,
        height: rect.height * 0.43
    )
    let shield = NSBezierPath()
    shield.move(to: NSPoint(x: shieldRect.midX, y: shieldRect.maxY))
    shield.curve(
        to: NSPoint(x: shieldRect.maxX, y: shieldRect.maxY - shieldRect.height * 0.18),
        controlPoint1: NSPoint(x: shieldRect.midX + shieldRect.width * 0.15, y: shieldRect.maxY),
        controlPoint2: NSPoint(x: shieldRect.maxX, y: shieldRect.maxY - shieldRect.height * 0.04)
    )
    shield.line(to: NSPoint(x: shieldRect.maxX, y: shieldRect.minY + shieldRect.height * 0.34))
    shield.curve(
        to: NSPoint(x: shieldRect.midX, y: shieldRect.minY),
        controlPoint1: NSPoint(x: shieldRect.maxX, y: shieldRect.minY + shieldRect.height * 0.15),
        controlPoint2: NSPoint(x: shieldRect.midX + shieldRect.width * 0.11, y: shieldRect.minY + shieldRect.height * 0.04)
    )
    shield.curve(
        to: NSPoint(x: shieldRect.minX, y: shieldRect.minY + shieldRect.height * 0.34),
        controlPoint1: NSPoint(x: shieldRect.midX - shieldRect.width * 0.11, y: shieldRect.minY + shieldRect.height * 0.04),
        controlPoint2: NSPoint(x: shieldRect.minX, y: shieldRect.minY + shieldRect.height * 0.15)
    )
    shield.line(to: NSPoint(x: shieldRect.minX, y: shieldRect.maxY - shieldRect.height * 0.18))
    shield.curve(
        to: NSPoint(x: shieldRect.midX, y: shieldRect.maxY),
        controlPoint1: NSPoint(x: shieldRect.minX, y: shieldRect.maxY - shieldRect.height * 0.04),
        controlPoint2: NSPoint(x: shieldRect.midX - shieldRect.width * 0.15, y: shieldRect.maxY)
    )
    shield.close()

    NSGraphicsContext.saveGraphicsState()
    shield.addClip()
    NSGradient(colors: [
        color(255, 255, 255, 0.96),
        color(220, 245, 243, 0.94)
    ])?.draw(in: shield, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    color(12, 70, 121, 0.12).setStroke()
    shield.lineWidth = rect.width * 0.01
    shield.stroke()

    let lockBodyRect = NSRect(
        x: shieldRect.midX - shieldRect.width * 0.18,
        y: shieldRect.minY + shieldRect.height * 0.24,
        width: shieldRect.width * 0.36,
        height: shieldRect.height * 0.26
    )
    let lockBody = roundedRectPath(in: lockBodyRect, radius: shieldRect.width * 0.05)
    color(23, 95, 160, 0.98).setFill()
    lockBody.fill()

    let shackleRect = NSRect(
        x: shieldRect.midX - shieldRect.width * 0.13,
        y: lockBodyRect.maxY - shieldRect.height * 0.02,
        width: shieldRect.width * 0.26,
        height: shieldRect.height * 0.22
    )
    let shackle = NSBezierPath()
    shackle.lineWidth = rect.width * 0.032
    shackle.lineCapStyle = .round
    shackle.move(to: NSPoint(x: shackleRect.minX, y: shackleRect.minY + shackleRect.height * 0.15))
    shackle.curve(
        to: NSPoint(x: shackleRect.maxX, y: shackleRect.minY + shackleRect.height * 0.15),
        controlPoint1: NSPoint(x: shackleRect.minX, y: shackleRect.maxY),
        controlPoint2: NSPoint(x: shackleRect.maxX, y: shackleRect.maxY)
    )
    color(23, 95, 160, 0.98).setStroke()
    shackle.stroke()

    let keyholeCircle = NSBezierPath(ovalIn: NSRect(
        x: shieldRect.midX - shieldRect.width * 0.045,
        y: lockBodyRect.minY + shieldRect.height * 0.09,
        width: shieldRect.width * 0.09,
        height: shieldRect.width * 0.09
    ))
    color(255, 255, 255, 0.95).setFill()
    keyholeCircle.fill()

    let keyholeStem = roundedRectPath(
        in: NSRect(
            x: shieldRect.midX - shieldRect.width * 0.025,
            y: lockBodyRect.minY + shieldRect.height * 0.04,
            width: shieldRect.width * 0.05,
            height: shieldRect.height * 0.11
        ),
        radius: shieldRect.width * 0.02
    )
    keyholeStem.fill()
}

func drawIcon(size: Int) throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGeneration", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法创建位图上下文"])
    }

    bitmap.size = NSSize(width: size, height: size)

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGeneration", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法创建绘图上下文"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let imageSize = NSSize(width: size, height: size)
    let canvas = NSRect(origin: .zero, size: imageSize)
    NSColor.clear.setFill()
    NSBezierPath(rect: canvas).fill()

    drawBackground(in: canvas)
    drawRepositoryCards(in: canvas)
    drawShield(in: canvas)

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法导出 PNG"])
    }

    try pngData.write(to: url)
}

for spec in specs {
    let bitmap = try drawIcon(size: spec.size)
    try writePNG(bitmap, to: outputDirectory.appendingPathComponent(spec.filename))
}

print("已生成 \(specs.count) 个图标文件到 \(outputDirectory.path)")
