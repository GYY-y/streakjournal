import SwiftUI

/// 点击某一天后查看当天完整记录（PRD 4.4.1 / 4.4.2）
struct RecordDetailSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(DateUtil.display(date, style: store.dateStyle))
                    .font(.title2.weight(.semibold))
                statusChips
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let relapseEvent = relapse {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(relapseTitle(relapseEvent))
                                .font(.callout.weight(.medium))
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                    }

                    if let cycle = cycleFor(date) {
                        LabeledRow("所属周期", cycleTitle(cycle))
                    } else {
                        LabeledRow("所属周期", store.relapseSet().contains(date) ? "破戒日（不属于任何周期）" : "不属于任何周期")
                    }

                    if let record = store.record(for: date) {
                        RecordContent(record: record)
                    } else {
                        Text("这一天没有留下记录。")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 480, height: 520)
    }

    private var relapse: RelapseEvent? {
        store.relapses.first { $0.date == date }
    }

    private var statusChips: some View {
        HStack(spacing: 6) {
            if store.cycleStartSet().contains(date) {
                Chip(text: "周期开始", selected: true)
            }
            if store.relapseSet().contains(date) {
                Chip(text: "破戒", selected: true, tint: .orange)
            }
            if store.record(for: date) != nil {
                Chip(text: "有记录", selected: true, tint: .teal)
            }
        }
    }

    private func cycleFor(_ date: String) -> Cycle? {
        for c in store.cycles {
            guard let d = DateUtil.days(from: c.startDate, to: date), d >= 0 else { continue }
            let end = c.endDate ?? store.todayKey
            if let e = DateUtil.days(from: date, to: end), e >= 0 {
                return c
            }
        }
        return nil
    }

    private func relapseTitle(_ r: RelapseEvent) -> String {
        if let note = r.note, !note.isEmpty {
            return "破戒日 · \(note)"
        }
        return "破戒日"
    }

    private func cycleTitle(_ c: Cycle) -> String {
        let start = DateUtil.display(c.startDate, style: store.dateStyle)
        if let end = c.endDate {
            return "开始于 \(start)，结束于 \(DateUtil.display(end, style: store.dateStyle))"
        }
        return "开始于 \(start)，进行中"
    }
}

struct RecordContent: View {
    let record: DailyRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let mood = record.mood {
                field("今日心态") { Chip(text: mood, selected: true) }
            }
            if !record.emotions.isEmpty {
                field("今日情绪") {
                    HStack(spacing: 6) {
                        ForEach(record.emotions, id: \.self) { Chip(text: $0, selected: true, tint: .purple) }
                    }
                }
            }
            if let state = record.state {
                field("今日状态") { Chip(text: state, selected: true, tint: .teal) }
            }

            let behavior = behaviorLines
            if !behavior.isEmpty {
                field("行为情况") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(behavior, id: \.self) { line in
                            Text(line).font(.system(size: 13))
                        }
                        if let note = record.behaviorNote {
                            Text("备注：\(note)").font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let p = record.perception {
                field("变化与感知") { Text(p).font(.system(size: 13)) }
            }
            if let t = record.freeText {
                field("自由记录") { Text(t).font(.system(size: 13)) }
            }

            Text("最后更新：\(DateUtil.displayDateTime(record.updatedAt))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var behaviorLines: [String] {
        var lines: [String] = []
        if let v = record.contactedPorn { lines.append("接触色情内容：\(v ? "是" : "否")") }
        if let v = record.targetBehavior { lines.append("发生目标行为：\(v ? "是" : "否")") }
        if let v = record.strongUrge { lines.append("出现明显冲动：\(v ? "是" : "否")") }
        return lines
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
