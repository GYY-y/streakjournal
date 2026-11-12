import SwiftUI
import AppKit

/// 勋章墙：连续徽章 + 累计徽章网格，新解锁时撒花庆祝
struct BadgesView: View {
    @EnvironmentObject private var store: Store
    /// 已解锁的勋章 id（逗号分隔持久化）
    @AppStorage("achievedBadges") private var achievedRaw: String = ""
    @State private var showConfetti = false
    /// 点击已解锁勋章弹出的大卡展示
    @State private var selectedBadge: BadgeDef?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                badgeSection(title: L("连续徽章"), icon: "flame.fill", badges: Badges.streak,
                             currentValue: store.longestStreak)
                badgeSection(title: L("累计徽章"), icon: "star.fill", badges: Badges.cumulative,
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
        .overlay {
            if let badge = selectedBadge {
                BadgeDetailOverlay(badge: badge) { selectedBadge = nil }
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
        store.lastMessage = L10n.f("🎉 恭喜解锁新勋章：%@", names)
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
                    BadgeCell(def: def, unlocked: isUnlocked(def, currentValue: currentValue)) {
                        guard isUnlocked(def, currentValue: currentValue) else { return }
                        selectedBadge = def
                    }
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
    var onTap: (() -> Void)?

    @State private var hovered = false

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
            .shadow(color: unlocked && hovered ? Color(red: 0.85, green: 0.70, blue: 0.28).opacity(0.45) : .clear, radius: 10)

            Text(def.localizedName)
                .font(.system(size: 13, weight: unlocked ? .semibold : .regular))
                .foregroundStyle(unlocked ? Color.primary : Color.secondary)
            Text(def.localizedRequirement)
                .font(.system(size: 11))
                .foregroundStyle(unlocked ? Color(red: 0.72, green: 0.55, blue: 0.13) : Color.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onTap?() }
        .cursor(unlocked ? .pointingHand : .arrow)
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

// MARK: - 点击勋章的展示大卡（仿参考样式）

/// 点击已获得勋章：深色大卡 + 放射光 + 聚焦在勋章上的撒花，点击遮罩或按 Esc 关闭
struct BadgeDetailOverlay: View {
    let badge: BadgeDef
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.5)
                    .onTapGesture(perform: onDismiss)

                VStack(spacing: 0) {
                    ZStack {
                        BadgeRays()
                            .frame(width: 220, height: 220)
                        Text(badge.emoji)
                            .font(.system(size: 76))
                            .shadow(color: Color(red: 0.55, green: 0.45, blue: 1.0).opacity(0.6), radius: 20)
                    }
                    .frame(height: 210)

                    Text(L("恭喜解锁新勋章！"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.62, green: 0.58, blue: 1.0))
                        .padding(.top, 4)

                    Text(badge.name)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    Text(badge.requirement)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.top, 10)
                }
                .padding(.top, 26)
                .padding(.bottom, 34)
                .padding(.horizontal, 26)
                .frame(width: 330)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.13, green: 0.10, blue: 0.26), Color(red: 0.06, green: 0.05, blue: 0.14)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 30, y: 14)
                .scaleEffect(appeared ? 1 : 0.82)
                .opacity(appeared ? 1 : 0)

                // 撒花聚焦在这枚勋章上（从勋章位置向四周迸发）
                BurstConfetti(origin: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 - 55))
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { appeared = true }
        }
        .onExitCommand { onDismiss() }   // Esc 关闭
    }
}

/// 勋章背后的放射光线（缓慢旋转 + 呼吸）
private struct BadgeRays: View {
    @State private var spinning = false
    @State private var pulsing = false

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.58, green: 0.52, blue: 1.0).opacity(0.05),
                                 Color(red: 0.58, green: 0.52, blue: 1.0).opacity(0.75)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 3.5, height: 60)
                    .offset(y: -92)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
        }
        .rotationEffect(.degrees(spinning ? 360 : 0))
        .opacity(pulsing ? 0.75 : 1)
        .onAppear {
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { spinning = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulsing = true }
        }
    }
}

// MARK: - 聚焦撒花：从勋章中心向四周迸发

struct BurstConfetti: View {
    let origin: CGPoint   // 迸发原点（勋章位置，画布坐标）

    private let start = Date()
    private let pieces: [BurstPiece] = {
        let colors: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink]
        return (0..<80).map { i in
            BurstPiece(
                angle: Double.random(in: 0...(2 * .pi)),
                speed: Double.random(in: 190...430),
                gravity: Double.random(in: 240...420),
                delay: Double.random(in: 0...0.25),
                size: Double.random(in: 6...12),
                color: colors[i % colors.count],
                isRect: Bool.random(),
                spin: Double.random(in: 3...8),
                phase: Double.random(in: 0...(2 * .pi))
            )
        }
    }()

    struct BurstPiece {
        let angle: Double     // 迸发方向
        let speed: Double     // 初速（pt/s）
        let gravity: Double   // 下坠加速度
        let delay: Double
        let size: Double
        let color: Color
        let isRect: Bool
        let spin: Double
        let phase: Double
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                _ = size
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let tt = t - p.delay
                    guard tt > 0, tt < 2.4 else { continue }
                    // 快速减速的迸发：d = speed * (1 - e^-kt)，越飞越慢
                    let d = p.speed * (1 - exp(-tt * 1.7))
                    let x = origin.x + cos(p.angle) * d
                    let y = origin.y + sin(p.angle) * d + 0.35 * p.gravity * tt * tt
                    let fade = tt > 1.6 ? max(0, 1 - (tt - 1.6) / 0.8) : 1
                    guard fade > 0 else { continue }
                    var ctx = context
                    ctx.opacity = fade
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

// MARK: - 鼠标指针样式辅助

extension View {
    /// 悬停时切换鼠标指针（用于可点击元素）
    @ViewBuilder
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { hovering in
            if hovering { cursor.push() } else { NSCursor.pop() }
        }
    }
}
