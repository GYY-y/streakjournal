import SwiftUI

// MARK: - 选项定义（PRD 4.2.2）

enum RecordOptions {
    static let moods = ["积极", "平静", "焦虑", "低落", "迷茫", "充实", "其他"]
    static let emotions = ["开心", "放松", "烦躁", "孤独", "压力大", "焦虑", "平静", "其他"]
    static let states = ["精力充沛", "注意力集中", "疲惫", "困倦", "状态一般", "其他"]
}

// MARK: - 参考图风格组件（彩色图标 + 分组行卡片 + 胶囊按钮）

/// 彩色圆角图标徽章
struct IconBadge: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26)
            .fill(LinearGradient(
                colors: [color.opacity(0.85), color],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.48, weight: .medium))
                    .foregroundStyle(.white)
            )
            .shadow(color: color.opacity(0.25), radius: 2, y: 1)
    }
}

/// 分组标题（卡片上方的小灰字）
struct GroupHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

/// 分组圆角卡片：行之间自动插入分隔线
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

/// 行内分隔线（左右留出图标缩进）
struct RowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 60)
    }
}

/// 设置行：图标 + 标题（+副标题）+ 右侧控件
struct SettingRow<Trailing: View>: View {
    let icon: String
    let color: Color
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: icon, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// 彩色胶囊按钮
struct PillButton: View {
    let title: String
    let color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 5)
                .background(Capsule().fill(color))
        }
        .buttonStyle(.plain)
    }
}

/// 右侧彩色数值文本
struct ValueText: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
    }
}

// MARK: - 通用小组件

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct Chip: View {
    let text: String
    var selected: Bool = false
    var tint: Color = .accentColor
    var action: (() -> Void)?

    var body: some View {
        let body = Text(text)
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(selected ? tint.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule().strokeBorder(selected ? tint.opacity(0.6) : Color.primary.opacity(0.10), lineWidth: 1)
            )
            .foregroundStyle(selected ? tint : Color.primary.opacity(0.75))

        if let action {
            Button(action: action) { body }
                .buttonStyle(.plain)
        } else {
            body
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

/// 三态选择（未填写 / 否 / 是）
struct TriStateField: View {
    let label: String
    @Binding var value: Bool?

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Picker(label, selection: triBinding) {
                Text("未填写").tag(-1)
                Text("否").tag(0)
                Text("是").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .labelsHidden()
        }
    }

    private var triBinding: Binding<Int> {
        Binding(
            get: {
                switch value {
                case .some(true): return 1
                case .some(false): return 0
                case .none: return -1
                }
            },
            set: {
                switch $0 {
                case 1: value = true
                case 0: value = false
                default: value = nil
                }
            }
        )
    }
}

/// Apple 风格日期字段：显示格式化日期，点击弹出日历面板选择
struct CalendarDateField: View {
    @Binding var date: Date
    var range: ClosedRange<Date>? = nil
    var maxWidth: CGFloat = 150

    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(DateUtil.key(date))
                    .font(.system(size: 13).monospacedDigit())
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            VStack {
                if let range {
                    DatePicker("", selection: $date, in: range, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(12)
                } else {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(12)
                }
            }
            .frame(width: 330)
            .onChange(of: date) { _, _ in
                showPicker = false
            }
        }
    }
}

/// 多行备注文本域（统一外观 + 占位符）
struct NoteEditor: View {
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 72

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 6)
                    .allowsHitTesting(false)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
    }
}

/// 三态选择（未填写 / 否 / 是）——胶囊样式，与选项 chips 一致
struct TriStateChips: View {
    let label: String
    @Binding var value: Bool?

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.8))
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                triChip(title: "未填写", isOn: value == nil) { value = nil }
                triChip(title: "否", isOn: value == false) { value = false }
                triChip(title: "是", isOn: value == true) { value = true }
            }
        }
    }

    private func triChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isOn ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
                )
                .overlay(
                    Capsule().strokeBorder(isOn ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.10), lineWidth: 1)
                )
                .foregroundStyle(isOn ? Color.accentColor : Color.primary.opacity(0.65))
        }
        .buttonStyle(.plain)
    }
}

/// 参考图风格彩色统计卡：小灰字标题 + 大彩色数字 + 副行
struct ColoredStatCard: View {
    let title: String
    let value: String
    let color: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

/// 参考图风格横向进度条排行（右侧带数值）
struct StatBarRow: View {
    let label: String
    let value: Int
    let fraction: Double
    var color: Color = .accentColor
    var unit: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
                Text("\(value)\(unit)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06))
                    Capsule().fill(color.opacity(0.85))
                        .frame(width: max(4, geo.size.width * min(1, fraction)))
                }
            }
            .frame(height: 6)
        }
    }
}

struct EmptyHint: View {
    let icon: String
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
