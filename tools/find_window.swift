import CoreGraphics
import Foundation

// 查找指定进程名的前台窗口 bounds
// 用法: swift -resource-dir ... find_window.swift <进程名>

let args = CommandLine.arguments
guard args.count >= 2 else { exit(1) }
let owner = args[1]

let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
for w in list {
    let name = w[kCGWindowOwnerName as String] as? String ?? ""
    if name == owner {
        let bounds = w[kCGWindowBounds as String] as! [String: Any]
        let layer = w[kCGWindowLayer as String] as? Int ?? -1
        guard layer == 0,
              let x = bounds["X"] as? Double,
              let y = bounds["Y"] as? Double,
              let width = bounds["Width"] as? Double,
              let height = bounds["Height"] as? Double,
              width > 100, height > 100 else { continue }
        print("\(Int(x)),\(Int(y)),\(Int(width)),\(Int(height))")
        exit(0)
    }
}
exit(2)
