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
    /// AI 对话：聊天 + 可选附件 + 生成任务
    @State private var showAIChat = false
    /// 是否为窄窗口：尺寸类 compact（iPhone）或窗口宽度偏窄（iPad 台前调度窄窗）。
    /// 台前调度的窄窗有时仍报 regular，仅靠 horizontalSizeClass 判断会漏，故叠加宽度判断。
    @State private var isNarrowWindow = false

    /// 窄窗口宽度阈值：小于该宽度按窄屏处理（单个分栏无法舒适并排）
    private static let narrowWindowWidth: CGFloat = 800

    /// 水平尺寸类：侧边栏手动切换按钮仅在窄屏显示，
    /// iPad regular 宽度下系统自动提供切换按钮
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var expandedState = ExpandedTaskState()
    @ObservedObject private var notifications = NotificationService.shared
    @ObservedObject private var backup = DataBackupManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 系统色彩方案（目标颜色 "auto" 适配：深色白 / 浅色黑）
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                GoalSidebarView(selectedGoal: $selectedGoal)
            } detail: {
                detail
                    // AI 导入按钮放在设置按钮左侧：导入文档自动生成任务清单
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showAIChat = true
                            } label: {
                                Image(systemName: "sparkles")
                            }
                            .accessibilityLabel("AI 对话并生成任务")
                            .disabled(selectedGoal == nil)
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel("设置")
                        }
                    }
                    // AI 对话对话框（多轮对话 + 可选附件 + 生成任务）
                    .sheet(isPresented: $showAIChat) {
                        if let goal = selectedGoal {
                            AIChatView(goal: goal)
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
                _ = DataBackupManager.shared.restoreIfNeeded(context: context)
            }
            .onChange(of: goals) { _, newGoals in
                // 目标列表变化后保证有选中项
                if selectedGoal == nil || !newGoals.contains(where: { $0.id == selectedGoal?.id }) {
                    selectedGoal = newGoals.first
                }
            }
            .onChange(of: selectedGoal) { _, newGoal in
                // 窄窗口（iPhone compact / iPad 台前调度窄窗）下选中目标后自动收起侧边栏、
                // 切回详情，否则点击目标后仍停留在目标列表，看不到目标界面。
                // 注意：compact 下 List(selection:) 已自动推入详情，此处 detailOnly 是双重保障；
                // 台前调度窄窗（仍报 regular）依赖此处的强制塌缩。
                if newGoal != nil && isNarrowWindow {
                    columnVisibility = .detailOnly
                }
            }
            .onChange(of: notifications.pendingTarget) { _, target in
                handleNotificationTap(target)
            }
            // 依据窗口实际宽度判定窄窗口（含 iPad 台前调度窄窗）
            .onAppear { isNarrowWindow = Self.isNarrow(proxy.size.width, horizontalSizeClass: horizontalSizeClass) }
            .onChange(of: proxy.size.width) { _, w in
                isNarrowWindow = Self.isNarrow(w, horizontalSizeClass: horizontalSizeClass)
            }
        }
    }

    /// 窄窗口判定：尺寸类 compact，或窗口宽度低于阈值
    private static func isNarrow(_ width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        horizontalSizeClass == .compact || width < narrowWindowWidth
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
            // 标题行：目标名（左）+ 截止倒计时（右，同高度右对齐）
            HStack(alignment: .center, spacing: 12) {
                Text(goal.name)
                    .font(.largeTitle.bold())
                    .lineLimit(1)
                Spacer(minLength: 12)
                if let endDate = goal.endDate {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("剩余时间")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let countdown = CountdownFormatter.countdown(
                                to: endDate,
                                preciseToHour: goal.endDatePreciseToHour,
                                now: context.date
                            ) {
                                Text(countdown)
                                    .font(.callout.weight(.semibold))
                                    .monospacedDigit()
                                    .accessibilityLabel("剩余时间：\(countdown)")
                            }
                            Text(
                                endDate,
                                format: goal.endDatePreciseToHour
                                    ? .dateTime.year().month().day().hour().minute()
                                    : .dateTime.year().month().day()
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

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
                    // 最右侧百分比（精确到小数点后 1 位）
                    Text("\(min(progress.fraction, 1) * 100, specifier: "%.1f")%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.footnote)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("总进度：已完成 \(Int(progress.completedWeight.rounded()))，共 \(progress.totalItems) 项，\(String(format: "%.1f", min(progress.fraction, 1) * 100))%")

            // 任务列表（无限层级）
            List {
                ForEach(sortedTasks(goal.tasks)) { task in
                    TaskRowView(task: task, depth: 0)
                }
            }
            .listStyle(.insetGrouped)
            .environmentObject(expandedState)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // 侧边栏切换按钮：仅窄窗口（iPhone compact / iPad 台前调度窄窗）显示；
                // iPad regular 宽度下系统自动提供切换按钮，手动添加会重复
                if isNarrowWindow {
                    Button {
                        columnVisibility = columnVisibility == .all ? .detailOnly : .all
                    } label: {
                        Image(systemName: "sidebar.leading")
                    }
                    .accessibilityLabel("目标列表")
                }
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
            .background(.regularMaterial, in: Circle())
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

    // MARK: - AI 对话
}
