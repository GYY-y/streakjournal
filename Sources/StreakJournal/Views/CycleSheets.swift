import SwiftUI

/// 开启新周期（PRD 4.1.2 / 4.3.2）
struct NewCycleSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var relapseMarked = true
    @State private var relapseNote = ""
    @State private var newStart = DateUtil.addDays(DateUtil.todayKey(), 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("开启新的周期"))
                .font(.title2.weight(.semibold))

            Text(L("结束当前周期后，之前的所有历史记录都会完整保留。"))
                .font(.callout)
                .foregroundStyle(.secondary)

            SectionCard(title: L("今天是否为破戒日")) {
                Picker("", selection: $relapseMarked) {
                    Text(L("是，标记为破戒事件")).tag(true)
                    Text(L("否，只是重新开始")).tag(false)
                }
                .pickerStyle(.radioGroup)

                if relapseMarked {
                    NoteEditor(text: $relapseNote, placeholder: L("破戒备注（可选）：发生了什么、当时的想法……"))
                    Text(L("破戒当天会作为独立记录保留，不计入任何周期的坚持天数。"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            SectionCard(title: L("新周期开始日期")) {
                HStack {
                    Button(L("今天")) { newStart = DateUtil.todayKey() }
                    Button(L("明天")) { newStart = DateUtil.addDays(DateUtil.todayKey(), 1) }
                    Spacer()
                }
                HStack(spacing: 12) {
                    Text(L("开始日期"))
                        .font(.system(size: 13))
                        .frame(width: 70, alignment: .leading)
                    CalendarDateField(
                        date: Binding(
                            get: { DateUtil.date(newStart) ?? Date() },
                            set: { newStart = DateUtil.key($0) }
                        )
                    )
                }
                if relapseMarked {
                    Text(L("若标记破戒，建议从明天开始新周期，让破戒当天保持独立。"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(summaryText)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L("取消")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("确认开启")) {
                    store.startNewCycle(
                        relapseMarked: relapseMarked,
                        relapseDate: DateUtil.todayKey(),
                        relapseNote: relapseNote.isEmpty ? nil : relapseNote,
                        newStart: newStart
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var summaryText: String {
        if relapseMarked {
            let relapseDate = DateUtil.todayKey()
            let activeEnd = DateUtil.addDays(relapseDate, -1)
            let hasActive = store.activeCycle != nil
            return hasActive
                ? LF("将执行：当前周期结束于 %@；%@ 记录为破戒日；新周期从 %@ 开始。", DateUtil.display(activeEnd, style: store.dateStyle), DateUtil.display(relapseDate, style: store.dateStyle), DateUtil.display(newStart, style: store.dateStyle))
                : LF("将执行：%@ 记录为破戒日；新周期从 %@ 开始。", DateUtil.display(relapseDate, style: store.dateStyle), DateUtil.display(newStart, style: store.dateStyle))
        } else {
            return LF("将执行：当前周期结束，新周期从 %@ 开始，不记录破戒事件。", DateUtil.display(newStart, style: store.dateStyle))
        }
    }
}

/// 补录破戒（PRD 4.3.3）
struct BackdatedRelapseSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var date = DateUtil.todayKey()
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("补录破戒"))
                .font(.title2.weight(.semibold))

            Text(L("如果忘记在当天标记，可以在这里补录。系统会调整对应的周期并重新计算。"))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text(L("破戒日期"))
                    .font(.system(size: 13))
                    .frame(width: 70, alignment: .leading)
                CalendarDateField(
                    date: Binding(
                        get: { DateUtil.date(date) ?? Date() },
                        set: { date = DateUtil.key($0) }
                    ),
                    range: Date.distantPast...Date()
                )
            }

            NoteEditor(text: $note, placeholder: L("备注（可选）：发生了什么、当时的想法……"))

            Text(L("补录后：当前周期结束于破戒日前一天；若破戒日在今天之前，将从次日重新开始计算。"))
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("确认补录")) {
                    store.markBackdatedRelapse(date: date, note: note.isEmpty ? nil : note)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
