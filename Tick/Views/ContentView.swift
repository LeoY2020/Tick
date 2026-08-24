import SwiftUI
import SwiftData

/// 展开状态（跨视图共享，供通知跳转时展开对应层级）
@MainActor
final class ExpandedTaskState: ObservableObject {
    /// 已展开任务的 id 集合
    @Published var expandedIDs: Set<UUID> = []
}

/// 主界面：侧边栏（目标列表）+ 目标详情（总进度 + 任务列表 + 底部添加按钮）
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Goal.createdAt) private var goals: [Goal]

    @State private var selectedGoal: Goal?
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var showSettings = false
    @State private var showAddTask = false

    /// 水平尺寸类：侧边栏手动切换按钮仅在窄屏（iPhone 等）显示，
    /// iPad regular 宽度下系统自动提供切换按钮
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var expandedState = ExpandedTaskState()
    @ObservedObject private var notifications = NotificationService.shared
    @ObservedObject private var backup = DataBackupManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 系统色彩方案（目标颜色 "auto" 适配：深色白 / 浅色黑）
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            GoalSidebarView(selectedGoal: $selectedGoal)
        } detail: {
            detail
                // 设置按钮挂载在主视图层：无目标（空态）与目标详情均可达
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("设置")
                    }
                }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(settings: SettingsStore.shared)
            }
        }
        .task {
            // 首次启动空库检测与恢复（Keychain / CloudKit 双轨）
            DataBackupManager.shared.restoreIfNeeded(context: context)
        }
        .onChange(of: goals) { _, newGoals in
            // 目标列表变化后保证有选中项
            if selectedGoal == nil || !newGoals.contains(where: { $0.id == selectedGoal?.id }) {
                selectedGoal = newGoals.first
            }
        }
        .onChange(of: notifications.pendingTarget) { _, target in
            handleNotificationTap(target)
        }
    }

    // MARK: - 详情区

    @ViewBuilder
    private var detail: some View {
        if let goal = selectedGoal {
            goalDetail(goal)
        } else if let first = goals.first {
            // 兜底：selectedGoal 短暂为 nil（如视图树重建）时直接渲染第一个目标，
            // 避免卡在加载指示器（goals 非空时 onChange 不触发，ProgressView 会无限转圈）
            goalDetail(first)
        } else {
            emptyState
        }
    }

    /// 空态：引导添加第一个目标
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("请先在侧边栏添加目标")
                .font(.headline)
            Button {
                columnVisibility = .all
            } label: {
                Label("添加目标", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("添加目标")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 目标详情：总进度 + 任务列表 + 底部添加按钮
    private func goalDetail(_ goal: Goal) -> some View {
        let progress = ProgressEngine.goalProgress(of: goal)
        let goalColor = HexColor.resolvedColor(from: goal.colorHex, colorScheme: colorScheme)

        return VStack(spacing: 0) {
            // 目标总进度区域
            VStack(spacing: 6) {
                // 进度条更新：贝塞尔曲线 0.5s 内完成
                ProgressView(value: progress.fraction)
                    .tint(goalColor)
                    .animation(reduceMotion ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.5), value: progress.fraction)
                HStack {
                    Text("已完成 \(Int(progress.completedWeight.rounded())) ")
                        .foregroundStyle(.secondary)
                    Text("共 \(progress.totalItems) 项")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.footnote)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("总进度：已完成 \(Int(progress.completedWeight.rounded()))，共 \(progress.totalItems) 项")

            // 任务列表（无限层级）
            List {
                ForEach(sortedTasks(goal.tasks)) { task in
                    TaskRowView(task: task, depth: 0)
                }
            }
            .listStyle(.insetGrouped)
            .environmentObject(expandedState)
        }
        .navigationTitle(goal.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // 侧边栏切换按钮：仅 iPhone 等窄屏（compact）显示；
                // iPad regular 宽度下系统自动提供切换按钮，手动添加会重复
                if horizontalSizeClass == .compact {
                    Button {
                        columnVisibility = columnVisibility == .all ? .detailOnly : .all
                    } label: {
                        Image(systemName: "sidebar.leading")
                    }
                    .accessibilityLabel("目标列表")
                }
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(goalColor)
                        .frame(width: 10, height: 10)
                    if let icon = goal.iconSystemName {
                        Image(systemName: icon)
                    }
                    Text(goal.name)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("目标：\(goal.name)")
            }
        }
        // 底部浮动添加任务按钮（Liquid Glass 中间层）
        .overlay(alignment: .bottom) {
            Button {
                showAddTask = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    // 随系统外观自适应：浅色模式黑加号 / 深色模式白加号
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
            }
            .glassEffect()
            .clipShape(Circle())
            .padding(.bottom, 24)
            .accessibilityLabel("添加任务")
        }
        .sheet(isPresented: $showAddTask) {
            QuickAddTaskView(goal: goal, parent: nil)
        }
        // 恢复中遮罩
        .overlay {
            if backup.isRestoring {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("恢复中…")
                            .font(.headline)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - 辅助

    /// 任务排序：sortOrder → createdAt
    private func sortedTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted {
            $0.sortOrder != $1.sortOrder ? $0.sortOrder < $1.sortOrder : $0.createdAt < $1.createdAt
        }
    }

    /// 通知点击跳转：定位目标并展开对应层级
    private func handleNotificationTap(_ target: ReminderTarget?) {
        guard let target else { return }
        // 切换到对应目标
        if let goal = goals.first(where: { $0.id == target.goalID }) {
            selectedGoal = goal
            // 沿 parentTask 链向上：展开每个祖先以显示目标任务
            var cursor = findTask(id: target.taskID, in: goal.tasks)
            while let current = cursor {
                if let parent = current.parentTask {
                    expandedState.expandedIDs.insert(parent.id)
                    cursor = parent
                } else {
                    break
                }
            }
        }
        notifications.pendingTarget = nil
    }

    /// 递归查找任务
    private func findTask(id: UUID, in tasks: [TaskItem]) -> TaskItem? {
        for task in tasks {
            if task.id == id { return task }
            if let found = findTask(id: id, in: task.subtasks) { return found }
        }
        return nil
    }
}
