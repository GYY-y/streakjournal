import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: Store
    @State private var quote = Quotes.random()
    @State private var showNewCycleSheet = false
    @State private var showBackdatedSheet = false

    /// 操作单选组：默认选中「坚持中」；选择动作项会弹出对应面板，结束后回到「坚持中」（内部用规范键比较）
    @State private var selectedAction = "坚持中"
    private let activeKey = "坚持中"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                streakCard
                actionPills
                if let cycle = store.activeCycle {
                    SectionCard(title: L("当前周期")) {
                        LabeledRow(L("开始日期"), DateUtil.display(cycle.startDate, style: store.dateStyle))
                        LabeledRow(L("周期状态"), cycle.isActive ? L("坚持中") : L("已结束"))
                        if store.goalDays > 0 {
                            ProgressView(value: min(Double(store.currentStreak), Double(store.goalDays)), total: Double(store.goalDays)) {
                                HStack {
                                    Text(LF("目标 %@ 天", "\(store.goalDays)")).font(.caption).foregroundStyle(.secondary)
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
            quote = Quotes.random()   // 每次进入首页都换一句
        }
        .sheet(isPresented: $showNewCycleSheet, onDismiss: { selectedAction = activeKey }) { NewCycleSheet() }
        .sheet(isPresented: $showBackdatedSheet, onDismiss: { selectedAction = activeKey }) { BackdatedRelapseSheet() }
    }

    // MARK: 子视图

    private var streakCard: some View {
        VStack(spacing: 10) {
            if let cycle = store.activeCycle {
                Text("\(store.currentStreak)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .monospacedDigit()
                Text(L("当前坚持天数"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Label(LF("开始于 %@", DateUtil.display(cycle.startDate, style: store.dateStyle)), systemImage: "calendar")
                    Label(LF("历史最长 %@ 天", "\(store.longestStreak)"), systemImage: "trophy")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text(L("还没有开始坚持周期"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(L("从今天开始，记录属于你的第一天。"))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Button(L("开启第一个周期")) {
                    store.startFirstCycle()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }

            // 哲学语录：作为主卡片的一部分，跟在数字/引导文案下方
            VStack(spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    Text(quote.text(L10n.shared.resolved))
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Text("—— \(quote.author(L10n.shared.resolved))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
            }
            .padding(.top, 6)
            .transition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }

    /// 单选胶囊组：三个选项同一配色（主题色高亮选中项），「坚持中」默认选中
    private var actionPills: some View {
        HStack(spacing: 10) {
            if store.activeCycle != nil {
                actionPill(L("坚持中"), key: activeKey, icon: "checkmark.circle.fill")
                actionPill(L("开启新的周期"), key: "开启新的周期", icon: "arrow.counterclockwise") {
                    showNewCycleSheet = true
                }
                actionPill(L("补录破戒"), key: "补录破戒", icon: "clock.badge.exclamationmark") {
                    showBackdatedSheet = true
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func actionPill(_ title: String, key: String, icon: String, action: (() -> Void)? = nil) -> some View {
        let isSelected = selectedAction == key
        return Button {
            selectedAction = key
            action?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.10), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.65))
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
