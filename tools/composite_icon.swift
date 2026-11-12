import AppKit

// 从 SVG 生成 macOS 应用图标（1024x1024 圆角矩形合成）+ 菜单栏小图标（36x36 透明）
// NSImage 在 macOS 11+ 原生支持 SVG（CoreSVG 矢量缩放）
// 用法：swift composite_icon.swift <SVG路径> <应用图标输出.png> <菜单栏图标输出.png>

let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write("用法: composite_icon.swift <SVG> <应用图标.png> <菜单栏图标.png>\n".data(using: .utf8)!)
    exit(1)
}

let svgPath = args[1]
let appIconPath = args[2]
let menuIconPath = args[3]

guard let svg = NSImage(contentsOfFile: svgPath) else {
    FileHandle.standardError.write("无法解析 SVG\n".data(using: .utf8)!)
    exit(4)
}

func makeRep(_ size: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
}

func savePNG(_ rep: NSBitmapImageRep, to path: String) -> Bool {
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    try? data.write(to: URL(fileURLWithPath: path))
    return FileManager.default.fileExists(atPath: path)
}

// MARK: 应用图标：圆角矩形背景 + 居中图案

let size = 1024
let rep = makeRep(size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let inset: CGFloat = 64
let rect = NSRect(x: inset, y: inset, width: CGFloat(size) - 2 * inset, height: CGFloat(size) - 2 * inset)

// 背景：圆角矩形 + 柔和绿色渐变（与图案配色呼应）
let bg = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.97, green: 0.99, blue: 0.94, alpha: 1.0),
                          ending: NSColor(calibratedRed: 0.76, green: 0.90, blue: 0.68, alpha: 1.0))
if let gradient {
    gradient.draw(in: bg, angle: -90)
}

// 内描边高光
let inner = NSBezierPath(roundedRect: rect.insetBy(dx: 10, dy: 10), xRadius: 200, yRadius: 200)
inner.lineWidth = 4
NSColor.white.withAlphaComponent(0.5).setStroke()
inner.stroke()

// 居中绘制图案（占背景约 74%）
let drawRect = rect.insetBy(dx: rect.width * 0.13, dy: rect.height * 0.13)
svg.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

guard savePNG(rep, to: appIconPath) else { exit(3) }

// MARK: 菜单栏小图标：纯图案透明底 36x36

let msize = 36
let mrep = makeRep(msize)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: mrep)
let mrect = NSRect(x: 2, y: 2, width: msize - 4, height: msize - 4)
svg.draw(in: mrect, from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard savePNG(mrep, to: menuIconPath) else { exit(5) }

print("应用图标已合成: \(appIconPath)；菜单栏图标: \(menuIconPath)")
