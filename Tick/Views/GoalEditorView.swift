import SwiftUI
import SwiftData

/// 色板条目（供 ForEach 稳定标识）
private struct PaletteSwatch: Identifiable {
    let name: String
    let hex: String
    var id: String { hex }
}

/// 图标选项（供 ForEach 稳定标识）
private struct IconOption: Identifiable {
    let symbol: String
    let name: String
    var id: String { symbol }
}

/// 目标属性快照（编辑前备份，取消时恢复）
private struct GoalSnapshot {
    let name: String
    let colorHex: String
    let iconSystemName: String?
    let startDate: Date?
    let endDate: Date?

    init(goal: Goal) {
        self.name = goal.name
        self.colorHex = goal.colorHex
        self.iconSystemName = goal.iconSystemName
        self.startDate = goal.startDate
        self.endDate = goal.endDate
    }
}

/// 目标编辑表单（新建 / 编辑复用）
struct GoalEditorView: View {
    @Bindable var goal: Goal
    /// 是否为新建目标（取消时回滚删除）
    let isNew: Bool
    /// 保存或取消后由调用方关闭 sheet
    var onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext

    /// 编辑前属性快照（编辑已有目标时记录，取消时恢复）
    @State private var snapshot: GoalSnapshot?

    /// 预设色板（HexColor.palette 12 色）
    private static let swatches: [PaletteSwatch] = HexColor.palette.map {
        PaletteSwatch(name: $0.name, hex: $0.hex)
    }

    /// 固定图标选项（SF Symbols，共 30 个）
    private static let icons: [IconOption] = [
        IconOption(symbol: "target", name: "目标"),
        IconOption(symbol: "flag", name: "旗帜"),
        IconOption(symbol: "star", name: "星标"),
        IconOption(symbol: "heart", name: "爱心"),
        IconOption(symbol: "book", name: "书本"),
        IconOption(symbol: "briefcase", name: "公文包"),
        IconOption(symbol: "figure.run", name: "跑步"),
        IconOption(symbol: "dumbbell", name: "健身"),
        IconOption(symbol: "pencil", name: "铅笔"),
        IconOption(symbol: "paintbrush", name: "画笔"),
        IconOption(symbol: "music.note", name: "音乐"),
        IconOption(symbol: "camera", name: "相机"),
        IconOption(symbol: "airplane", name: "飞机"),
        IconOption(symbol: "car", name: "汽车"),
        IconOption(symbol: "cart", name: "购物"),
        IconOption(symbol: "creditcard", name: "银行卡"),
        IconOption(symbol: "gift", name: "礼物"),
        IconOption(symbol: "graduationcap", name: "学业"),
        IconOption(symbol: "leaf", name: "自然"),
        IconOption(symbol: "moon", name: "月亮"),
        IconOption(symbol: "sun", name: "太阳"),
        IconOption(symbol: "clock", name: "时钟"),
        IconOption(symbol: "calendar", name: "日程"),
        IconOption(symbol: "house", name: "家庭"),
        IconOption(symbol: "phone", name: "电话"),
        IconOption(symbol: "envelope", name: "邮件"),
        IconOption(symbol: "gamecontroller", name: "游戏"),
        IconOption(symbol: "wineglass", name: "酒杯"),
        IconOption(symbol: "cup.and.saucer", name: "咖啡"),
        IconOption(symbol: "fork.knife", name: "餐饮"),
    ]

    /// 色板网格列（6 列 × 2 行）
    private static let colorColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 0),
        count: 6
    )

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 基本信息
                Section("基本信息") {
                    TextField("名称", text: $goal.name, prompt: Text("请输入名称"))
                        .accessibilityLabel("目标名称")
                }

                // MARK: 颜色
                Section("颜色") {
                    // 自动 + 预设 12 色板：固定 44×44 触控目标，适配动态字体
                    LazyVGrid(columns: Self.colorColumns, spacing: 0) {
                        autoColorButton
                        ForEach(Self.swatches) { swatch in
                            paletteButton(swatch)
                        }
                    }
                    .padding(.vertical, 4)

                    ColorPicker("自定义", selection: customColor, supportsOpacity: false)
                        .accessibilityLabel("自定义颜色")
                }

                // MARK: 图标
                Section("图标") {
                    Menu {
                        Picker("图标", selection: iconSelection) {
                            Text("无图标").tag("")
                            ForEach(Self.icons) { option in
                                Label(option.name, systemImage: option.symbol)
                                    .tag(option.symbol)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        LabeledContent("图标") {
                            currentIconLabel
                        }
                    }
                    .accessibilityLabel("选择图标")
                    .accessibilityValue(currentIconName)
                }

                // MARK: 日期
                Section("日期") {
                    Toggle("开始日期", isOn: hasStartDate)
                        .accessibilityLabel("启用开始日期")
                    if goal.startDate != nil {
                        DatePicker("开始日期", selection: startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    Toggle("截止日期", isOn: hasEndDate)
                        .accessibilityLabel("启用截止日期")
                    if goal.endDate != nil {
                        DatePicker("截止日期", selection: endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }
            }
            .navigationTitle(isNew ? "新建目标" : "编辑目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel)
                        .accessibilityLabel("取消编辑")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!isNameValid) // 名称必填
                        .accessibilityLabel("保存目标")
                }
            }
        }
        // 禁止下滑关闭：必须通过取消 / 保存退出，避免新建目标残留在数据中
        .interactiveDismissDisabled()
        .onAppear {
            // 编辑已有目标时记录快照，供取消恢复
            if !isNew {
                snapshot = GoalSnapshot(goal: goal)
            }
        }
    }

    // MARK: - 子视图

    /// 自动颜色按钮：半黑半白圆形（左黑右白），选中显示描边环与勾选徽章；
    /// "auto" 语义 = 深色模式白 / 浅色模式黑
    private var autoColorButton: some View {
        let isSelected = isSelectedColor(HexColor.autoHex)
        return Button {
            goal.colorHex = HexColor.autoHex
        } label: {
            ZStack {
                if isSelected {
                    Circle() // 选中描边环（primary 随外观自适应，黑白背景均可见）
                        .strokeBorder(Color.primary.opacity(0.55), lineWidth: 2.5)
                        .frame(width: 34, height: 34)
                }
                // 半黑半白圆形（左黑右白）
                HStack(spacing: 0) {
                    Rectangle().fill(Color.black)
                    Rectangle().fill(Color.white)
                }
                .frame(width: 26, height: 26)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                )
                if isSelected {
                    // 勾选徽章（白底黑勾，在黑白两半上均清晰）
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(2)
                        .background(Circle().fill(.white))
                }
            }
            .frame(width: 44, height: 44) // 固定触控目标
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("自动颜色")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// 色板圆形按钮：选中时显示勾选与描边环
    private func paletteButton(_ swatch: PaletteSwatch) -> some View {
        let color = HexColor.color(from: swatch.hex)
        let isSelected = isSelectedColor(swatch.hex)
        return Button {
            goal.colorHex = swatch.hex
        } label: {
            ZStack {
                if isSelected {
                    Circle() // 选中描边环
                        .strokeBorder(color, lineWidth: 2.5)
                        .frame(width: 34, height: 34)
                }
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isLightColor(swatch.hex) ? .black : .white)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 44, height: 44) // 固定触控目标
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(swatch.name)颜色")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// 图标行右侧当前值
    @ViewBuilder
    private var currentIconLabel: some View {
        if let symbol = goal.iconSystemName {
            Label(currentIconName, systemImage: symbol)
                .foregroundStyle(.secondary)
        } else {
            Text("无图标")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 状态判定

    /// 名称去除首尾空白后非空才允许保存
    private var isNameValid: Bool {
        !goal.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 当前是否选中色板中的指定颜色（忽略大小写）
    private func isSelectedColor(_ hex: String) -> Bool {
        goal.colorHex.uppercased() == hex.uppercased()
    }

    /// 当前图标的中文显示名（未知符号回退显示符号名）
    private var currentIconName: String {
        guard let symbol = goal.iconSystemName else { return "无图标" }
        return Self.icons.first { $0.symbol == symbol }?.name ?? symbol
    }

    /// 颜色是否偏亮（决定勾选符号用黑或白，保证对比度）
    private func isLightColor(_ hex: String) -> Bool {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return false }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b > 0.7
    }

    // MARK: - Binding 桥接

    /// 自定义颜色（与 colorHex 双向转换）
    private var customColor: Binding<Color> {
        Binding(
            get: { HexColor.color(from: goal.colorHex) },
            set: { goal.colorHex = HexColor.hex(from: $0) }
        )
    }

    /// 图标选择（空字符串代表"无图标"，写入 nil）
    private var iconSelection: Binding<String> {
        Binding(
            get: { goal.iconSystemName ?? "" },
            set: { goal.iconSystemName = $0.isEmpty ? nil : $0 }
        )
    }

    /// 是否设置开始日期（关闭时置 nil）
    private var hasStartDate: Binding<Bool> {
        Binding(
            get: { goal.startDate != nil },
            set: { goal.startDate = $0 ? (goal.startDate ?? Date()) : nil }
        )
    }

    private var startDate: Binding<Date> {
        Binding(
            get: { goal.startDate ?? Date() },
            set: { goal.startDate = $0 }
        )
    }

    /// 是否设置截止日期（关闭时置 nil）
    private var hasEndDate: Binding<Bool> {
        Binding(
            get: { goal.endDate != nil },
            set: { goal.endDate = $0 ? (goal.endDate ?? Date()) : nil }
        )
    }

    private var endDate: Binding<Date> {
        Binding(
            get: { goal.endDate ?? Date() },
            set: { goal.endDate = $0 }
        )
    }

    // MARK: - 操作

    /// 取消：新建目标删除回滚；编辑已有目标恢复编辑前快照
    private func cancel() {
        if isNew {
            modelContext.delete(goal)
        } else if let snap = snapshot {
            goal.name = snap.name
            goal.colorHex = snap.colorHex
            goal.iconSystemName = snap.iconSystemName
            goal.startDate = snap.startDate
            goal.endDate = snap.endDate
        }
        try? modelContext.save()
        onFinished()
    }

    /// 保存：名称去除首尾空白后持久化；数据变更 → 同步 Keychain 备份
    private func save() {
        goal.name = goal.name.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        DataBackupManager.shared.backupAppData(context: modelContext)
        onFinished()
    }
}
