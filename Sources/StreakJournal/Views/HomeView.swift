import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var nav: AppNav
    @State private var encouragement = ""
    @State private var showNewCycleSheet = false
    @State private var showBackdatedSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                streakCard
                encouragementCard
                todayCard
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
                recentRecords
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

    private var todayCard: some View {
        SectionCard(title: "今日状态") {
            HStack {
                if store.activeCycle != nil {
                    Label(
                        store.hasRecordToday ? "今天已经记录" : "今天还没有记录",
                        systemImage: store.hasRecordToday ? "checkmark.circle.fill" : "circle.dashed"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(store.hasRecordToday ? .green : .secondary)
                }
                Spacer()
            }

            if store.activeCycle != nil {
                HStack(spacing: 12) {
                    Button {
                        showNewCycleSheet = true
                    } label: {
                        Label("开启新的周期", systemImage: "arrow.counterclockwise")
                    }
                    Button {
                        showBackdatedSheet = true
                    } label: {
                        Label("补录破戒", systemImage: "clock.badge.exclamationmark")
                    }
                    Spacer()
                    Button {
                        nav.page = .record
                    } label: {
                        Label(store.hasRecordToday ? "编辑今日记录" : "填写今日记录", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text("「继续坚持」无需任何操作——只要不开启新周期，坚持天数会自然延续。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var recentRecords: some View {
        SectionCard(title: "最近的记录") {
            if store.records.isEmpty {
                Text("还没有任何记录。每一天的心情、状态和想法，都值得留下来。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(store.records.prefix(5)) { r in
                    HStack(spacing: 12) {
                        IconBadge(systemImage: "square.and.pencil", color: .blue, size: 28)
                        Text(DateUtil.display(r.date, style: store.dateStyle))
                            .font(.system(size: 13).monospacedDigit())
                            .frame(width: 110, alignment: .leading)
                        if let mood = r.mood {
                            Chip(text: mood, selected: true)
                        }
                        Text(r.freeText ?? r.perception ?? r.state ?? "（仅结构化记录）")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
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
