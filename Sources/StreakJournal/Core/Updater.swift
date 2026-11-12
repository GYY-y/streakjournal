import Foundation

/// 检查更新：对比 GitHub 最新 Release 的版本号与当前应用版本
/// 有新版本时引导用户前往 Releases 页面下载 DMG（不做自动替换安装，避免安全与签名问题）
enum Updater {
    static let repo = "GYY-y/streakjournal"

    /// 当前版本（来自 Info.plist CFBundleShortVersionString，由构建脚本写入）
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var releasePageURL: URL {
        URL(string: "https://github.com/\(repo)/releases/latest")!
    }

    /// 版本号比较（按点分段数字）：-1 = a 较旧，0 = 相同，1 = a 较新
    static func compare(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }

    /// 拉取最新版本；有更新返回新版本号字符串，无更新/解析失败返回 nil
    static func fetchLatestVersion() async throws -> String? {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        req.timeoutInterval = 15
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String else { return nil }
        let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        return compare(currentVersion, latest) < 0 ? latest : nil
    }
}
