import AppKit

// 生成应用图标：蓝底圆环 + 对勾（1024x1024 PNG）
// 用法：swift tools/make_icon.swift <输出路径>

let size = 1024
let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("用法: swift make_icon.swift <输出.png>\n".data(using: .utf8)!)
    exit(1)
}
let outputPath = args[1]

guard let rep = NSBitmapImageRep(
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

// 背景：圆角矩形
let bg = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 1.0).setFill()
bg.fill()

// 顶部高光渐变
let gradient = NSGradient(starting: NSColor.white.withAlphaComponent(0.18),
                          ending: NSColor.white.withAlphaComponent(0.0))
if let gradient {
    gradient.draw(in: bg, angle: -90)
}

// 白色圆环
let ringRect = NSRect(x: 262, y: 262, width: 500, height: 500)
let ring = NSBezierPath(ovalIn: ringRect)
ring.lineWidth = 52
NSColor.white.withAlphaComponent(0.95).setStroke()
ring.stroke()

// 进度弧（约 3/4 圈）
let arc = NSBezierPath()
arc.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 250, startAngle: 90, endAngle: -160, clockwise: true)
arc.lineWidth = 52
arc.lineCapStyle = .round
NSColor.white.setStroke()
arc.stroke()

// 对勾
let check = NSBezierPath()
check.lineWidth = 62
check.lineCapStyle = .round
check.lineJoinStyle = .round
check.move(to: NSPoint(x: 400, y: 520))
check.line(to: NSPoint(x: 490, y: 425))
check.line(to: NSPoint(x: 645, y: 585))
NSColor.white.setStroke()
check.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { exit(3) }
try data.write(to: URL(fileURLWithPath: outputPath))
print("图标已生成: \(outputPath)")
