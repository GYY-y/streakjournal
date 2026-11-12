import Foundation

/// 哲学语录：首页与菜单栏展示，每次出现随机抽取一句
struct Quote {
    let zhHans: String
    let zhHant: String
    let en: String
    let authorZh: String
    let authorEn: String

    func text(_ resolved: L10n.Resolved) -> String {
        switch resolved {
        case .zhHans: return zhHans
        case .zhHant: return zhHant
        case .en: return en
        }
    }

    func author(_ resolved: L10n.Resolved) -> String {
        switch resolved {
        case .zhHans, .zhHant: return authorZh
        case .en: return authorEn
        }
    }
}

enum Quotes {
    static let all: [Quote] = [
        Quote(
            zhHans: "千里之行，始于足下。", zhHant: "千里之行，始於足下。",
            en: "A journey of a thousand miles begins beneath one's feet.",
            authorZh: "老子", authorEn: "Laozi"),
        Quote(
            zhHans: "天行健，君子以自强不息。", zhHant: "天行健，君子以自強不息。",
            en: "As heaven moves with vigor, the noble person strives without rest.",
            authorZh: "《周易》", authorEn: "I Ching"),
        Quote(
            zhHans: "锲而舍之，朽木不折；锲而不舍，金石可镂。", zhHant: "鍥而捨之，朽木不折；鍥而不捨，金石可鏤。",
            en: "Carve without stopping, and even metal and stone can be engraved.",
            authorZh: "荀子", authorEn: "Xunzi"),
        Quote(
            zhHans: "不积跬步，无以至千里；不积小流，无以成江海。", zhHant: "不積跬步，無以至千里；不積小流，無以成江海。",
            en: "Without small steps, you cannot reach a thousand miles; without small streams, no sea can form.",
            authorZh: "荀子", authorEn: "Xunzi"),
        Quote(
            zhHans: "逝者如斯夫，不舍昼夜。", zhHant: "逝者如斯夫，不捨晝夜。",
            en: "Time flows on like this river, never ceasing day or night.",
            authorZh: "孔子", authorEn: "Confucius"),
        Quote(
            zhHans: "吾日三省吾身。", zhHant: "吾日三省吾身。",
            en: "Each day I examine myself on three counts.",
            authorZh: "曾子", authorEn: "Zengzi"),
        Quote(
            zhHans: "知人者智，自知者明。", zhHant: "知人者智，自知者明。",
            en: "Knowing others is wisdom; knowing yourself is enlightenment.",
            authorZh: "老子", authorEn: "Laozi"),
        Quote(
            zhHans: "志不立，天下无可成之事。", zhHant: "志不立，天下無可成之事。",
            en: "Without resolve, nothing in the world can be accomplished.",
            authorZh: "王阳明", authorEn: "Wang Yangming"),
        Quote(
            zhHans: "用志不分，乃凝于神。", zhHant: "用志不分，乃凝於神。",
            en: "Focus without distraction, and the spirit gathers into one.",
            authorZh: "庄子", authorEn: "Zhuangzi"),
        Quote(
            zhHans: "性格即命运。", zhHant: "性格即命運。",
            en: "Character is destiny.",
            authorZh: "赫拉克利特", authorEn: "Heraclitus"),
        Quote(
            zhHans: "未经省察的人生不值得过。", zhHant: "未經省察的人生不值得過。",
            en: "The unexamined life is not worth living.",
            authorZh: "苏格拉底", authorEn: "Socrates"),
        Quote(
            zhHans: "你所拥有的一切，只是当下。", zhHant: "你所擁有的一切，只是當下。",
            en: "Confine yourself to the present.",
            authorZh: "马可·奥勒留", authorEn: "Marcus Aurelius"),
        Quote(
            zhHans: "我们不是缺少时间，而是挥霍了时间。", zhHant: "我們不是缺少時間，而是揮霍了時間。",
            en: "It is not that we have a short time to live, but that we waste much of it.",
            authorZh: "塞涅卡", authorEn: "Seneca"),
        Quote(
            zhHans: "不要希望事情如你所愿，要愿其所如。", zhHant: "不要希望事情如你所願，要願其所如。",
            en: "Don't seek for things to happen as you wish; wish for things to happen as they do.",
            authorZh: "爱比克泰德", authorEn: "Epictetus"),
        Quote(
            zhHans: "知道为什么而活的人，便能承受几乎任何一种生活。", zhHant: "知道為什麼而活的人，便能承受幾乎任何一種生活。",
            en: "He who has a why to live can bear almost any how.",
            authorZh: "尼采", authorEn: "Nietzsche"),
        Quote(
            zhHans: "对未来的真正慷慨，是把一切献给现在。", zhHant: "對未來的真正慷慨，是把一切獻給現在。",
            en: "Real generosity toward the future lies in giving all to the present.",
            authorZh: "加缪", authorEn: "Camus"),
        Quote(
            zhHans: "世界上只有一种真正的英雄主义，就是在认清生活真相之后依然热爱生活。", zhHant: "世界上只有一種真正的英雄主義，就是在認清生活真相之後依然熱愛生活。",
            en: "There is only one heroism in the world: to see the world as it is and to love it.",
            authorZh: "罗曼·罗兰", authorEn: "Romain Rolland"),
        Quote(
            zhHans: "哪有什么胜利可言，挺住意味着一切。", zhHant: "哪有什麼勝利可言，挺住意味著一切。",
            en: "Who talks of victory? To endure is everything.",
            authorZh: "里尔克", authorEn: "Rilke"),
        Quote(
            zhHans: "生命只能倒着被理解，但必须正着被经历。", zhHant: "生命只能倒著被理解，但必須正著被經歷。",
            en: "Life can only be understood backwards; but it must be lived forwards.",
            authorZh: "克尔凯郭尔", authorEn: "Kierkegaard"),
        Quote(
            zhHans: "做你自己，因为别人都有人做了。", zhHant: "做你自己，因為別人都有人做了。",
            en: "Be yourself; everyone else is already taken.",
            authorZh: "王尔德", authorEn: "Oscar Wilde"),
        Quote(
            zhHans: "天空没有留下翅膀的痕迹，但我已飞过。", zhHant: "天空沒有留下翅膀的痕跡，但我已飛過。",
            en: "I leave no trace of wings in the air, but I am glad I have had my flight.",
            authorZh: "泰戈尔", authorEn: "Tagore"),
        Quote(
            zhHans: "我愿意深深地扎入生活，吮尽生活的骨髓。", zhHant: "我願意深深地扎入生活，吮盡生活的骨髓。",
            en: "I wanted to live deep and suck out all the marrow of life.",
            authorZh: "梭罗", authorEn: "Thoreau"),
    ]

    /// 随机抽取一句（每次调用都可能不同）
    static func random() -> Quote {
        all.randomElement() ?? all[0]
    }
}
