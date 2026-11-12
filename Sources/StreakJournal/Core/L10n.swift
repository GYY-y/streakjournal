import Foundation

/// 应用内国际化：简体中文（基准键）/ 繁體中文 / English
/// 语言偏好持久化到 UserDefaults（appLanguage），"system" 跟随系统首选语言。
/// 词典键 = 简体中文字符串；缺词条时回退键本身（简体）。
final class L10n: ObservableObject {
    static let shared = L10n()

    enum Lang: String, CaseIterable, Identifiable {
        case system, zhHans, zhHant, en
        var id: String { rawValue }
    }

    enum Resolved { case zhHans, zhHant, en }

    @Published var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage") }
    }

    private init() {
        lang = Lang(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system
    }

    var resolved: Resolved { Self.resolve(lang) }

    /// "system" 时按系统首选语言解析（zh-Hant/zh-TW/zh-HK → 繁体，en → 英语，其余 → 简体）
    static func resolve(_ l: Lang) -> Resolved {
        switch l {
        case .zhHans: return .zhHans
        case .zhHant: return .zhHant
        case .en: return .en
        case .system:
            let preferred = (Locale.preferredLanguages.first ?? "zh-Hans").lowercased()
            if preferred.hasPrefix("zh") {
                return preferred.contains("hant") || preferred.contains("-tw") || preferred.contains("-hk") || preferred.contains("-mo") ? .zhHant : .zhHans
            }
            return preferred.hasPrefix("en") ? .en : .zhHans
        }
    }

    /// 翻译一个固定字符串
    static func t(_ key: String) -> String {
        let l = L10n.shared.resolved
        guard l != .zhHans else { return key }
        return table[l]?[key] ?? key
    }

    /// 带参数翻译：pattern 中用 %@ 占位，按顺序替换
    static func f(_ pattern: String, _ args: [String]) -> String {
        var s = t(pattern)
        for a in args {
            if let r = s.range(of: "%@") {
                s = s.replacingOccurrences(of: "%@", with: a, options: .literal, range: r)
            }
        }
        return s
    }

    // MARK: - 词典

    static let table: [Resolved: [String: String]] = [
        .zhHant: zhHantTable,
        .en: enTable,
    ]
}

/// 全局便捷翻译函数
func L(_ key: String) -> String { L10n.t(key) }
func LF(_ pattern: String, _ args: String...) -> String { L10n.f(pattern, args) }