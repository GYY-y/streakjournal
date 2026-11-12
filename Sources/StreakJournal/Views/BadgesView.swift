import SwiftUI

/// 勋章墙：连续徽章 + 累计徽章网格，新解锁时撒花庆祝
struct BadgesView: View {
    @EnvironmentObject private var store: Store
    /// 已解锁的勋章 id（逗号分隔持久化）
    @AppStorage("achievedBadges") private var achievedRaw: String = ""
    @State private var showConfetti = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                badgeSection(title: "连续徽章", icon: "flame.fill", badges: Badges.streak,
                             currentValue: store.longestStreak)
                badgeSection(title: "累计徽章", icon: "star.fill", badges: Badges.cumulative,
                             currentValue: store.records.count)
            }
            .padding(24)
        }
        .overlay {
            if showConfetti {
                ConfettiOverlay()
                    .allowsHitTesting(false)
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation(.easeIn(duration: 0.3)) { showConfetti = false }
                    }
            }
        }
        .onAppear(perform: checkNewBadges)
    }

    // MARK: 解锁检测

    private func checkNewBadges() {
        var achieved = Set(achievedRaw.split(separator: ",").map(String.init))
        let newly = Badges.all.filter { def in
            let value: Int
            switch def.kind {
            case .streak: value = store.longestStreak
            case .cumulative: value = store.records.count
            }
            return value >= def.threshold && !achieved.contains(def.id)
        }
        guard !newly.isEmpty else { return }
        newly.forEach { achieved.insert($0.id) }
        achievedRaw = achieved.joined(separator: ",")
        let names = newly.map(\.name).joined(separator: "、")
        store.lastMessage = "🎉 恭喜解锁新勋章：\(names)"
        showConfetti = true
    }

    private func isUnlocked(_ def: BadgeDef, currentValue: Int) -> Bool {
        currentValue >= def.threshold
    }

    // MARK: 分组区块

    private func badgeSection(title: String, icon: String, badges: [BadgeDef], currentValue: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.13))
                Spacer()
                Text("\(badges.filter { isUnlocked($0, currentValue: currentValue) }.count)/\(badges.count)")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            let columns = [GridItem(.adaptive(minimum: 130), spacing: 20)]
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(badges) { def in
                    BadgeCell(def: def, unlocked: isUnlocked(def, currentValue: currentValue))
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

// MARK: 单个勋章

private struct BadgeCell: View {
    let def: BadgeDef
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlocked ? Color(red: 1.0, green: 0.96, blue: 0.82) : Color.primary.opacity(0.05))
                Circle()
                    .strokeBorder(unlocked ? Color(red: 0.85, green: 0.70, blue: 0.28) : Color.primary.opacity(0.12),
                                  lineWidth: unlocked ? 3 : 2)
                Text(def.emoji)
                    .font(.system(size: 40))
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.35)
            }
            .frame(width: 84, height: 84)

            Text(def.name)
                .font(.system(size: 13, weight: unlocked ? .semibold : .regular))
                .foregroundStyle(unlocked ? Color.primary : Color.secondary)
            Text(def.requirement)
                .font(.system(size: 11))
                .foregroundStyle(unlocked ? Color(red: 0.72, green: 0.55, blue: 0.13) : Color.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: 撒花动画

/// 全屏撒花：彩纸从顶部飘落并旋转，约 3 秒结束
struct ConfettiOverlay: View {
    private let start = Date()
    private let pieces: [Piece] = {
        let colors: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink]
        return (0..<70).map { i in
            Piece(
                x: Double.random(in: 0...1),
                delay: Double.random(in: 0...0.6),
                fallSpeed: Double.random(in: 0.45...0.95),
                sway: Double.random(in: 20...55),
                swayFreq: Double.random(in: 1.5...3.5),
                phase: Double.random(in: 0...(2 * .pi)),
                size: Double.random(in: 6...13),
                color: colors[i % colors.count],
                isRect: Bool.random(),
                spin: Double.random(in: 2...6)
            )
        }
    }()

    struct Piece {
        let x: Double          // 0~1 相对横向位置
        let delay: Double
        let fallSpeed: Double  // 每秒下落比例
        let sway: Double       // 左右摆幅（pt）
        let swayFreq: Double
        let phase: Double
        let size: Double
        let color: Color
        let isRect: Bool
        let spin: Double       // 每秒旋转弧度
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let tt = t - p.delay
                    guard tt > 0 else { continue }
                    let y = -20 + tt * p.fallSpeed * (size.height + 60)
                    let x = p.x * size.width + sin(tt * p.swayFreq + p.phase) * p.sway
                    let opacity = y > size.height * 0.8 ? max(0, (size.height + 20 - y) / (size.height * 0.25)) : 1
                    guard opacity > 0, y < size.height + 20 else { continue }
                    var ctx = context
                    ctx.opacity = opacity
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(tt * p.spin + p.phase))
                    let rect = CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.isRect ? p.size * 0.55 : p.size)
                    let path = p.isRect ? Path(roundedRect: rect, cornerRadius: 1.5) : Path(ellipseIn: rect)
                    ctx.fill(path, with: .color(p.color))
                }
            }
        }
        .ignoresSafeArea()
    }
}
