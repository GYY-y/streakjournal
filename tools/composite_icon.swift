import AppKit

// 把 SVG 渲染出的透明 PNG 合成到圆角矩形背景上，生成 macOS 应用图标（1024x1024）
// 用法：swift composite_icon.swift <原始透明PNG> <输出PNG>

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("用法: composite_icon.swift <原始PNG> <输出PNG>\n".data(using: .utf8)!)
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]
let size = 1024

guard let image = NSImage(contentsOfFile: inputPath), let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else { exit(2) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let inset: CGFloat = 64
let rect = NSRect(x: inset, y: inset, width: CGFloat(size) - 2 * inset, height: CGFloat(size) - 2 * inset)

// 背景：圆角矩形 + 柔和绿色渐变（与恐龙配色呼应）
let bg = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.95, green: 0.99, blue: 0.93, alpha: 1.0),
                          ending: NSColor(calibratedRed: 0.78, green: 0.91, blue: 0.72, alpha: 1.0))
if let gradient {
    gradient.draw(in: bg, angle: -90)
}

// 内描边高光
let inner = NSBezierPath(roundedRect: rect.insetBy(dx: 10, dy: 10), xRadius: 200, yRadius: 200)
inner.lineWidth = 4
NSColor.white.withAlphaComponent(0.5).setStroke()
inner.stroke()

// 居中绘制恐龙图案（占背景约 76%）
let drawRect = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.12)
let imgSize = image.size
let scale = min(drawRect.width / imgSize.width, drawRect.height / imgSize.height)
let w = imgSize.width * scale, h = imgSize.height * scale
let target = NSRect(x: drawRect.midX - w / 2, y: drawRect.midY - h / 2, width: w, height: h)
image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { exit(3) }
try data.write(to: URL(fileURLWithPath: outputPath))
print("应用图标已合成: \(outputPath)")
