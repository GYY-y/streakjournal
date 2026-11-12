import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: Store
    @State private var encouragement = ""
    @State private var showNewCycleSheet = false
    @State private var showBackdatedSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                streakCard
                encouragementCard
                actionPills
                if let cycle = store.activeCycle {
                    SectionCard(title: "当前周期") {
                        LabeledRow("开始日期", DateUtil.display(cycle.startDate, style: store.dateStyle))
                        LabeledRow("周期状态", cycle.isActive ? "坚持中" : "已结束")
                        if store.goalDays > 0 {
                            ProgressView(value: min(Double(store.currentStreak), Double(store.goalDays)), total: Double(store.goalDays)) {
                                HStack {
                                    Text("目标 \(store.goalDays) 天").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    ValueText(text: "\(min(store.currentStreak, store.goalDays))/\(store.goalDays)", color: .green)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            encouragement = Encouragement.message(days: store.currentStreak)
        }
        .sheet(isPresented: $showNewCycleSheet) { NewCycleSheet() }
        .sheet(isPresented: $showBackdatedSheet) { BackdatedRelapseSheet() }
    }

    // MARK: 子视图

    private var streakCard: some View {
        VStack(spacing: 10) {
            if let cycle = store.activeCycle {
                Text("\(store.currentStreak)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .monospacedDigit()
                Text("当前坚持天数")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Label("开始于 \(DateUtil.display(cycle.startDate, style: store.dateStyle))", systemImage: "calendar")
                    Label("历史最长 \(store.longestStreak) 天", systemImage: "trophy")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("还没有开始坚持周期")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("从今天开始，记录属于你的第一天。")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Button("开启第一个周期") {
                    store.startFirstCycle()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private var encouragementCard: some View {
        HStack {
            Image(systemName: "quote.opening")
                .foregroundStyle(.tertiary)
            Text(encouragement)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.06)))
    }

    /// 椭圆形操作按钮行：「坚持中」默认选中，「开启新的周期」「补录破戒」可点击
    private var actionPills: some View {
        HStack(spacing: 12) {
            if store.activeCycle != nil {
                // 状态胶囊：默认选中
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("坚持中")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.green.opacity(0.15)))
                .overlay(Capsule().strokeBorder(Color.green.opacity(0.55), lineWidth: 1))
                .foregroundStyle(.green)

                pillButton(title: "开启新的周期", icon: "arrow.counterclockwise", tint: .accentColor) {
                    showNewCycleSheet = true
                }
                pillButton(title: "补录破戒", icon: "clock.badge.exclamationmark", tint: .orange) {
                    showBackdatedSheet = true
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pillButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Capsule().fill(tint.opacity(0.10)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1))
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }
}

struct LabeledRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13))
        }
    }
}
