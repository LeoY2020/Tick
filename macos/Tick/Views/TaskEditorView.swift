import SwiftUI
import SwiftData

/// 图标候选（供 ForEach 稳定标识，元组不支持 keypath）
private struct IconOption: Identifiable {
    let symbol: String
    let name: String
    var id: String { symbol }
}

/// 色板条目（供 ForEach 稳定标识）
private struct PaletteSwatch: Identifiable {
    let name: String
    let hex: String
    var id: String { hex }
}

/// 任务属性快照（编辑前备份，取消时恢复）
private struct TaskSnapshot {
    let name: String
    let colorHex: String?
    let iconSystemName: String?
    let typeRaw: String
    let statusRaw: String
    let totalAmount: Double
    let currentAmount: Double
    let startDate: Date?
    let endDate: Date?
    let reminderDate: Date?
    let repeatRuleRaw: String?
    let customWeekdaysRaw: String?

    init(task: TaskItem) {
        self.name = task.name
        self.colorHex = task.colorHex
        self.iconSystemName = task.iconSystemName
        self.typeRaw = task.typeRaw
        self.statusRaw = task.statusRaw
        self.totalAmount = task.totalAmount
        self.currentAmount = task.currentAmount
        self.startDate = task.startDate
        self.endDate = task.endDate
        self.reminderDate = task.reminderDate
        self.repeatRuleRaw = task.repeatRuleRaw
        self.customWeekdaysRaw = task.customWeekdaysRaw
    }

    /// 恢复快照到任务（取消编辑时调用）
    func apply(to task: TaskItem) {
        task.name = name
        task.colorHex = colorHex
        task.iconSystemName = iconSystemName
        task.typeRaw = typeRaw
        task.statusRaw = statusRaw
        task.totalAmount = totalAmount
        task.currentAmount = currentAmount
        task.startDate = startDate
        task.endDate = endDate
        task.reminderDate = reminderDate
        task.repeatRuleRaw = repeatRuleRaw
        task.customWeekdaysRaw = customWeekdaysRaw
    }
}

/// 任务编辑表单：完整属性编辑（名称/类型/状态/进度/提醒/颜色/图标/日期覆盖）。
/// 接管机制：有子任务时状态/进度控件只读，由子任务计算/汇总。
struct TaskEditorView: View {
    @Bindable var task: TaskItem
    /// 保存或取消后由调用方关闭 sheet
    var onFinished: () -> Void

    @Environment(\.modelContext) private var context
    @ObservedObject private var notifications = NotificationService.shared

    // MARK: - 本地编辑状态

    /// 编辑前属性快照（取消时恢复）
    @State private var snapshot: TaskSnapshot?
    /// 提醒开关
    @State private var reminderOn = false
    /// 重复规则（nil = 不重复）
    @State private var repeatRule: RepeatRule? = nil
    /// 自定义周几选中集合（1=周日…7=周六）
    @State private var selectedWeekdays: Set<Int> = []
    /// 颜色覆盖开关
    @State private var overrideColor = false
    /// 图标覆盖开关
    @State private var overrideIcon = false
    /// 进度总量文本
    @State private var totalText = ""

    /// 图标候选（与 GoalEditorView 保持一致）
    private static let iconOptions: [IconOption] = [
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

    /// 预设色板（HexColor.palette 12 色，包装为可标识结构体）
    private static let swatches: [PaletteSwatch] = HexColor.palette.map {
        PaletteSwatch(name: $0.name, hex: $0.hex)
    }

    private static let colorColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 0), count: 6
    )

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                if task.type == .single { statusSection }
                if task.type == .progress { progressSection }
                reminderSection
                appearanceSection
                dateSection
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel)
                        .accessibilityLabel("取消编辑")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!canSave)
                        .accessibilityLabel("保存任务")
                }
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            // 记录编辑前快照（取消时恢复）
            snapshot = TaskSnapshot(task: task)
            syncLocalStates()
        }
    }

    // MARK: - Section

    /// 基本信息：名称 + 类型
    private var basicSection: some View {
        Section("基本信息") {
            TextField("名称", text: $task.name, prompt: Text("请输入名称"))
                .accessibilityLabel("任务名称")
            Picker("类型", selection: $task.type) {
                ForEach(TaskType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("任务类型")
        }
    }

    /// 状态（单项专用；接管时只读）
    private var statusSection: some View {
        Section {
            Picker("状态", selection: $task.status) {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .disabled(task.hasSubtasks)
            .accessibilityLabel("任务状态")
        } header: {
            Text("状态")
        } footer: {
            if task.hasSubtasks {
                Text("状态由子任务计算")
            }
        }
    }

    /// 进度（进度类型专用；接管时只读并显示汇总值）
    private var progressSection: some View {
        Section {
            TextField("总量", text: $totalText)
                .keyboardType(.numberPad)
                .disabled(task.hasSubtasks)
                .accessibilityLabel("进度总量")
            if task.hasSubtasks {
                // 接管：显示汇总值（总量 = 子任务总量之和）
                let progress = ProgressEngine.effectiveProgress(of: task)
                LabeledContent("当前进度") {
                    Text("\(Int(progress.current))/\(Int(progress.total))")
                        .monospacedDigit()
                }
                ProgressView(value: progress.total > 0 ? progress.current / progress.total : 0)
            } else {
                Stepper("当前进度 \(Int(task.currentAmount))",
                        value: Binding(
                            get: { task.currentAmount },
                            set: { task.setProgress($0) }
                        ),
                        in: 0...max(task.totalAmount, 1))
                    .accessibilityLabel("调整进度")
                ProgressView(value: task.totalAmount > 0 ? task.currentAmount / task.totalAmount : 0)
            }
        } header: {
            Text("进度")
        } footer: {
            if task.hasSubtasks {
                Text("进度由子任务汇总（总量 = 子任务总量之和）")
            }
        }
    }

    /// 提醒：时间 + 重复规则 + 自定义周几
    private var reminderSection: some View {
        Section {
            Toggle("开启提醒", isOn: $reminderOn)
                .accessibilityLabel("开启提醒")
                .onChange(of: reminderOn) { _, enabled in
                    if enabled {
                        task.reminderDate = task.reminderDate ?? Date()
                    } else {
                        task.reminderDate = nil
                        task.repeatRule = nil
                        NotificationService.shared.cancelReminders(taskID: task.id)
                    }
                }
            if reminderOn {
                DatePicker("提醒时间", selection: reminderDateBinding, displayedComponents: [.date, .hourAndMinute])
                    .accessibilityLabel("提醒时间")
                Picker("重复规则", selection: $repeatRule) {
                    Text("不重复").tag(RepeatRule?.none)
                    ForEach(RepeatRule.allCases.filter { $0 != .custom }, id: \.self) { rule in
                        Text(rule.displayName).tag(RepeatRule?.some(rule))
                    }
                    Text("自定义").tag(RepeatRule?.some(.custom))
                }
                .accessibilityLabel("重复规则")
                if repeatRule == .custom {
                    weekdayPicker
                }
            }
            if NotificationService.shared.authorizationDenied {
                denialHint
            }
        } header: {
            Text("提醒")
        }
    }

    /// 自定义周几多选（1=周日…7=周六，标签用系统短星期名）
    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("周几多选")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { weekday in
                    let isSelected = selectedWeekdays.contains(weekday)
                    Button {
                        toggleWeekday(weekday)
                    } label: {
                        Text(weekdayLabel(weekday))
                            .font(.subheadline)
                            .frame(width: 40, height: 40)
                            .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("每\(weekdayLabel(weekday))提醒")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }

    /// 通知权限被拒提示 + 前往系统设置
    private var denialHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("通知权限已被拒绝，请前往系统设置开启")
                .font(.footnote)
                .foregroundStyle(.red)
            Button("前往设置") {
                // macOS：打开通知设置面板
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.footnote)
        }
    }

    /// 外观：颜色/图标覆盖（关闭 = 继承父级）
    private var appearanceSection: some View {
        Section("外观") {
            Toggle("覆盖颜色", isOn: $overrideColor)
                .accessibilityLabel("覆盖颜色")
                .onChange(of: overrideColor) { _, enabled in
                    if !enabled { task.colorHex = nil }
                }
            if overrideColor {
                LazyVGrid(columns: Self.colorColumns, spacing: 0) {
                    ForEach(Self.swatches) { swatch in
                        paletteButton(swatch.hex, name: swatch.name)
                    }
                }
                .padding(.vertical, 4)
                ColorPicker("自定义", selection: customColorBinding, supportsOpacity: false)
                    .accessibilityLabel("自定义颜色")
            }
            Toggle("覆盖图标", isOn: $overrideIcon)
                .accessibilityLabel("覆盖图标")
                .onChange(of: overrideIcon) { _, enabled in
                    if !enabled { task.iconSystemName = nil }
                }
            if overrideIcon {
                Menu {
                    Picker("图标", selection: iconSelection) {
                        Text("无图标").tag("")
                        ForEach(Self.iconOptions) { icon in
                            Label(icon.name, systemImage: icon.symbol).tag(icon.symbol)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    LabeledContent("图标") {
                        if let symbol = task.iconSystemName {
                            Label(iconDisplayName(symbol), systemImage: symbol)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("无图标").foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityLabel("选择图标")
            }
        }
    }

    /// 日期覆盖（关闭 = 继承父级）
    private var dateSection: some View {
        Section("日期") {
            Toggle("开始日期", isOn: hasStartDate)
                .accessibilityLabel("覆盖开始日期")
            if task.startDate != nil {
                DatePicker("开始日期", selection: startDateBinding, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .accessibilityLabel("开始日期")
            }
            Toggle("截止日期", isOn: hasEndDate)
                .accessibilityLabel("覆盖截止日期")
            if task.endDate != nil {
                DatePicker("截止日期", selection: endDateBinding, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .accessibilityLabel("截止日期")
            }
        }
    }

    // MARK: - 色板按钮

    private func paletteButton(_ hex: String, name: String) -> some View {
        let color = HexColor.color(from: hex)
        let isSelected = task.colorHex?.uppercased() == hex.uppercased()
        return Button {
            task.colorHex = hex
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .strokeBorder(color, lineWidth: 2.5)
                        .frame(width: 34, height: 34)
                }
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name)颜色")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 状态同步与校验

    /// onAppear：从模型同步本地编辑状态
    private func syncLocalStates() {
        reminderOn = task.reminderDate != nil
        repeatRule = task.repeatRule
        selectedWeekdays = Set(task.effectiveWeekdays())
        overrideColor = task.colorHex != nil
        overrideIcon = task.iconSystemName != nil
        totalText = task.totalAmount > 0 ? String(Int(task.totalAmount)) : ""
    }

    /// 保存可用：名称非空；进度类型时总量为正整数（接管时忽略总量校验）
    private var canSave: Bool {
        guard !task.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if task.type == .progress && !task.hasSubtasks {
            guard let total = Int(totalText), total > 0 else { return false }
        }
        return true
    }

    /// 星期标签（1=周日…7=周六，取系统短星期名）
    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols // [日,一,二,三,四,五,六]（随 locale）
        return symbols[weekday - 1]
    }

    /// 切换周几选中
    private func toggleWeekday(_ weekday: Int) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
        task.customWeekdaysRaw = selectedWeekdays.isEmpty
            ? nil
            : selectedWeekdays.sorted().map(String.init).joined(separator: ",")
    }

    private func iconDisplayName(_ symbol: String) -> String {
        Self.iconOptions.first { $0.symbol == symbol }?.name ?? symbol
    }

    // MARK: - Binding 桥接

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: { task.reminderDate ?? Date() },
            set: { task.reminderDate = $0 }
        )
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { task.colorHex.map { HexColor.color(from: $0) } ?? .black },
            set: { task.colorHex = HexColor.hex(from: $0) }
        )
    }

    private var iconSelection: Binding<String> {
        Binding(
            get: { task.iconSystemName ?? "" },
            set: { task.iconSystemName = $0.isEmpty ? nil : $0 }
        )
    }

    private var hasStartDate: Binding<Bool> {
        Binding(
            get: { task.startDate != nil },
            set: { task.startDate = $0 ? (task.startDate ?? Date()) : nil }
        )
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { task.startDate ?? Date() },
            set: { task.startDate = $0 }
        )
    }

    private var hasEndDate: Binding<Bool> {
        Binding(
            get: { task.endDate != nil },
            set: { task.endDate = $0 ? (task.endDate ?? Date()) : nil }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { task.endDate ?? Date() },
            set: { task.endDate = $0 }
        )
    }

    // MARK: - 保存 / 取消

    /// 取消：恢复编辑前快照并持久化，提醒按快照状态重新同步
    private func cancel() {
        if let snap = snapshot {
            snap.apply(to: task)
        }
        try? context.save()
        DataBackupManager.shared.backupAppData(context: context)

        // 提醒以快照恢复结果为准：清除编辑期注册的通知，有提醒则重新注册
        NotificationService.shared.cancelReminders(taskID: task.id)
        if task.reminderDate != nil, let goal = ProgressEngine.rootGoal(of: task) {
            let task = self.task
            let goalName = goal.name
            Task { @MainActor in
                await NotificationService.shared.scheduleReminder(for: task, goalName: goalName)
            }
        }
        onFinished()
    }

    private func save() {
        task.name = task.name.trimmingCharacters(in: .whitespacesAndNewlines)
        // 进度总量（接管时保留子任务汇总，忽略手动输入）
        if task.type == .progress && !task.hasSubtasks {
            if let total = Int(totalText), total > 0 {
                task.totalAmount = Double(total)
                task.setProgress(task.currentAmount)
            }
        }
        // 重复规则回落：关闭提醒或选"不重复"时清空
        if !reminderOn {
            task.repeatRule = nil
            task.customWeekdaysRaw = nil
        } else {
            task.repeatRule = repeatRule
            if repeatRule != .custom { task.customWeekdaysRaw = nil }
        }

        try? context.save()
        DataBackupManager.shared.backupAppData(context: context)

        // 提醒变更 → 重新注册通知（权限被拒时服务内部忽略注册）
        if reminderOn, let goal = ProgressEngine.rootGoal(of: task) {
            Task { @MainActor in
                _ = await NotificationService.shared.requestAuthorization()
                await NotificationService.shared.scheduleReminder(for: task, goalName: goal.name)
            }
        }
        onFinished()
    }
}
