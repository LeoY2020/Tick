import SwiftUI
import SwiftData

/// 目标侧边栏：切换 / 新增 / 删除目标
struct GoalSidebarView: View {
    /// 当前选中的目标（与主内容区双向绑定）
    @Binding var selectedGoal: Goal?
    /// 侧边栏列可见性（窄屏点击目标后收起侧边栏并展示详情）
    @Binding var columnVisibility: NavigationSplitViewVisibility

    /// 全部目标（按创建时间升序）
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    /// 数据上下文（插入 / 删除目标）
    @Environment(\.modelContext) private var modelContext
    /// 水平尺寸类：窄屏（iPhone 等 compact）点击目标后收起侧边栏
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 正在编辑的目标（非 nil 时呈现编辑 sheet）
    @State private var editingGoal: Goal?
    /// 当前编辑 sheet 是否为新建目标
    @State private var editingIsNew = false
    /// 待确认删除的目标（非 nil 时呈现确认对话框）
    @State private var goalToDelete: Goal?

    var body: some View {
        List {
            Section("目标") {
                ForEach(goals) { goal in
                    goalRow(goal)
                }
            }

            Section {
                // 列表末尾"添加目标"入口
                Button(action: addGoal) {
                    Label("添加目标", systemImage: "plus.circle")
                }
                .accessibilityLabel("添加目标")
            }
        }
        .listStyle(.sidebar)
        // 侧边栏（目标切换界面）标题：使用 SwiftUI 自带导航标题样式
        .navigationTitle("目标")
        // 目标编辑 sheet（新建 / 编辑复用）
        .sheet(item: $editingGoal) { goal in
            GoalEditorView(goal: goal, isNew: editingIsNew) {
                editingGoal = nil
            }
        }
        // 删除前二次确认
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: deleteDialogPresented,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let goal = goalToDelete {
                    deleteGoal(goal)
                }
            }
            Button("取消", role: .cancel) {
                goalToDelete = nil
            }
        }
    }

    // MARK: - 行视图

    /// 单个目标行：颜色圆点 + 图标 + 名称，点击切换选中
    private func goalRow(_ goal: Goal) -> some View {
        let isSelected = selectedGoal == goal
        return Button {
            selectedGoal = goal
            // 窄屏（iPhone 等 compact）下：点击目标后自动收起侧边栏、展示目标详情。
            // 直接在此处理而非依赖 onChange，避免"点击已选中目标"时 selection 不变而不触发。
            if horizontalSizeClass == .compact {
                columnVisibility = .detailOnly
            }
        } label: {
            HStack(spacing: 10) {
                // 颜色圆点（直径 12，"auto" 随系统外观自适应）
                AdaptiveColorDot(hex: goal.colorHex)
                    .accessibilityHidden(true)
                // 目标图标（未设置时不显示）
                if let iconName = goal.iconSystemName {
                    Image(systemName: iconName)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                Text(goal.name)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44) // 触控目标 ≥ 44pt
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 选中行高亮背景
        .listRowBackground(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                        .padding(.vertical, 2)
                }
            }
        )
        // 长按 / 右键菜单：编辑、删除
        .contextMenu {
            Button {
                editingIsNew = false
                editingGoal = goal
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                goalToDelete = goal
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityLabel("目标\(goal.name)")
        .accessibilityHint("轻点两下切换到该目标")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 操作

    /// 新建目标：插入空目标并以新建模式打开编辑 sheet
    private func addGoal() {
        let goal = Goal()
        modelContext.insert(goal)
        editingIsNew = true
        editingGoal = goal
    }

    /// 删除目标：级联删除其下全部任务；若删除当前选中目标，切换到剩余第一个（或 nil）
    private func deleteGoal(_ goal: Goal) {
        // 先按现有顺序计算剩余目标（删除后 @Query 不一定同步刷新）
        let remaining = goals.filter { $0 != goal }
        if selectedGoal == goal {
            selectedGoal = remaining.first
        }
        modelContext.delete(goal) // tasks 关系为 cascade，级联删除任务
        try? modelContext.save()
        // 数据变更 → 同步 Keychain 备份
        DataBackupManager.shared.backupAppData(context: modelContext)
        goalToDelete = nil
    }

    // MARK: - 删除确认

    /// 确认对话框标题（含目标名称）
    private var deleteDialogTitle: String {
        guard let goal = goalToDelete else { return "删除目标" }
        return "删除目标「\(goal.name)」？其下所有任务将被一并删除。"
    }

    /// 由 goalToDelete 派生的对话框呈现绑定
    private var deleteDialogPresented: Binding<Bool> {
        Binding(
            get: { goalToDelete != nil },
            set: { if !$0 { goalToDelete = nil } }
        )
    }
}
