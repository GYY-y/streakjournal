import SwiftUI

struct RecordView: View {
    @EnvironmentObject private var store: Store

    @State private var currentDate = DateUtil.todayKey()
    @State private var draft = DailyRecord(date: "", mood: nil, emotions: [], state: nil, perception: nil, freeText: nil, contactedPorn: nil, targetBehavior: nil, strongUrge: nil, behaviorNote: nil, updatedAt: "")
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                dateBar
                if store.relapseSet().contains(currentDate) {
                    relapseBanner
                }
                SectionCard(title: L("今日心态（单选）")) {
                    FlowChips(options: RecordOptions.moods, selected: draft.mood) { draft.mood = ($0 == draft.mood) ? nil : $0 }
                }
                SectionCard(title: L("今日情绪（可多选）")) {
                    FlowChips(options: RecordOptions.emotions, selected: nil, multiSelected: draft.emotions) { item in
                        if draft.emotions.contains(item) {
                            draft.emotions = draft.emotions.filter { $0 != item }
                        } else {
                            draft.emotions.append(item)
                        }
                    }
                }
                SectionCard(title: L("今日状态")) {
                    FlowChips(options: RecordOptions.states, selected: draft.state) { draft.state = ($0 == draft.state) ? nil : $0 }
                }
                SectionCard(title: L("今日行为情况（可不填，各字段独立记录）")) {
                    TriStateChips(label: LF("是否接触%@", Store.shared.behaviorLabel), value: $draft.contactedPorn)
                    Divider().padding(.vertical, 6)
                    TriStateChips(label: L("是否发生目标行为"), value: $draft.targetBehavior)
                    Divider().padding(.vertical, 6)
                    TriStateChips(label: L("是否出现明显冲动"), value: $draft.strongUrge)
                    Divider().padding(.vertical, 6)
                    Text(L("备注"))
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.8))
                    NoteEditor(text: Binding(
                        get: { draft.behaviorNote ?? "" },
                        set: { draft.behaviorNote = $0.isEmpty ? nil : $0 }
                    ), placeholder: L("与行为相关的备注（可选）……"), minHeight: 60)
                }
                SectionCard(title: L("今日变化与感知")) {
                    NoteEditor(text: Binding(
                        get: { draft.perception ?? "" },
                        set: { draft.perception = $0.isEmpty ? nil : $0 }
                    ), placeholder: L("今天感受到了什么变化？例如：工作时注意力比较集中 / 精神状态不错 / 有些疲惫…"), minHeight: 70)
                }
                SectionCard(title: L("自由记录")) {
                    NoteEditor(text: Binding(
                        get: { draft.freeText ?? "" },
                        set: { draft.freeText = $0.isEmpty ? nil : $0 }
                    ), placeholder: L("今天发生了什么、想了什么、遇到什么问题……不受模板限制，写你想留下的。"), minHeight: 140)
                }

                footerBar
            }
            .padding(24)
        }
        .onAppear(perform: loadDraft)
        .onChange(of: currentDate) { _, _ in loadDraft() }
        .onChange(of: draft) { _, _ in scheduleSave() }
    }

    // MARK: 子视图

    private var dateBar: some View {
        HStack(spacing: 16) {
            Spacer()

            // 左右箭头紧贴日期两侧
            HStack(spacing: 10) {
                Button { currentDate = DateUtil.addDays(currentDate, -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                CalendarDateField(
                    date: Binding(
                        get: { DateUtil.date(currentDate) ?? Date() },
                        set: { currentDate = DateUtil.key($0) }
                    ),
                    range: Date.distantPast...Date()
                )

                Button { currentDate = DateUtil.addDays(currentDate, 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(currentDate >= store.todayKey)
            }

            Spacer()

            Button(L("回到今天")) { currentDate = store.todayKey }
                .buttonStyle(.borderless)
                .disabled(currentDate == store.todayKey)
        }
        .padding(.vertical, 4)
    }

    private var relapseBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(L("这一天被标记为破戒日。当天的记录会独立保存。"))
                .font(.callout)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.10)))
    }

    private var footerBar: some View {
        HStack {
            if let saved = store.lastSavedAt, !draftIsNew {
                Spacer()
                Text(LF("已保存 %@", saved.formatted(date: .omitted, time: .standard)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private var draftIsNew: Bool {
        store.record(for: currentDate) == nil
    }

    // MARK: 逻辑

    private func loadDraft() {
        if let existing = store.record(for: currentDate) {
            draft = existing
        } else {
            draft = DailyRecord(date: currentDate, mood: nil, emotions: [], state: nil, perception: nil, freeText: nil, contactedPorn: nil, targetBehavior: nil, strongUrge: nil, behaviorNote: nil, updatedAt: "")
        }
    }

    /// 自动保存：停止输入 0.8 秒后落库（内容无变化时不重复保存）
    private func scheduleSave() {
        guard !draft.date.isEmpty else { return }
        if store.record(for: currentDate) == draft { return }
        saveTask?.cancel()
        let snapshot = draft
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            var toSave = snapshot
            toSave.date = currentDate
            store.saveRecord(toSave)
        }
    }
}

// MARK: - 流式选项 chips

struct FlowChips: View {
    let options: [String]
    var selected: String?
    var multiSelected: [String] = []
    var action: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSel = multiSelected.contains(option) || option == selected
                Chip(text: L(option), selected: isSel) { action(option) }
            }
        }
    }
}

/// 简单流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
