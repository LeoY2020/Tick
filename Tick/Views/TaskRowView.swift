import SwiftUI
import SwiftData

/// 单个任务行：递归渲染子任务（无限层级），接管机制下父任务控件只读
struct TaskRowView: View {
    @Bindable var task: TaskItem
    /// 层级深度（缩进依据）
    let depth: Int

    @EnvironmentObject private var expandedState: ExpandedTaskState
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showAddSubtask = false
    @State private var taskToDelete: TaskItem?

    var body: some View {
        if task.hasSubtasks {
            // 有子任务：DisclosureGroup 展开/折叠（接管机制生效）
            DisclosureGroup(isExpanded: expansionBinding) {
                ForEach(sortedSubtasks) { sub in
                    TaskRowView(task: sub, depth: depth + 1)
                }
            } label: {
                rowContent
            }
        } else {
            // 叶子任务
            rowContent
        }
    }

    // MARK: - 行内容

    private var rowContent: some View {
        HStack(spacing: 10) {
            // 颜色标识（继承链解析）
            Circle()
                .fill(HexColor.color(from: ProgressEngine.effectiveColor(of: task)))
                .frame(width: 12, height: 12)

            // 图标（继承链解析）
            if let icon = ProgressEngine.effectiveIcon(of: task) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }

            // 名称
            Text(task.name)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .opacity(isDeletedSingle ? 0.4 : 1)
                .strikethrough(isDeletedSingle)

            Spacer(minLength: 8)

            // 尾部控件（单项状态 / 进度，接管时只读）
            trailingControl
        }
        .padding(.leading, min(Double(depth) * 16.0, 64.0))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                showAddSubtask = true
            } label: {
                Label("添加子任务", systemImage: "plus.circle")
            }
            .tint(.blue)
            .accessibilityLabel("添加子任务")
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                taskToDelete = task
            } label: {
                Label("删除", systemImage: "trash")
            }
            .accessibilityLabel("删除任务")
        }
        .contextMenu {
            Button {
                showAddSubtask = true
            } label: {
                Label("添加子任务", systemImage: "plus.circle")
            }
            Button(role: .destructive) {
                taskToDelete = task
            } label: {
                Label("删除任务", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "删除任务「\(task.name)」？其所有子任务将一并删除。",
            isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                deleteTask()
                taskToDelete = nil
            }
            Button("取消", role: .cancel) {
                taskToDelete = nil
            }
        }
        .sheet(isPresented: $showAddSubtask) {
            QuickAddTaskView(
                goal: ProgressEngine.rootGoal(of: task) ?? parentGoalFallback,
                parent: task
            )
        }
    }

    // MARK: - 尾部控件

    /// 删除态单项判定
    private var isDeletedSingle: Bool {
        task.type == .single && task.status == .deleted
    }

    @ViewBuilder
    private var trailingControl: some View {
        if task.type == .single {
            singleControl
        } else {
            progressControl
        }
    }

    /// 单项任务：状态菜单（有子任务时只读，状态由子任务计算）
    private var singleControl: some View {
        let effective = ProgressEngine.effectiveStatus(of: task)
        return Menu {
            ForEach(TaskStatus.allCases, id: \.self) { status in
                Button {
                    task.status = status
                    persistAndBackup()
                } label: {
                    Label(status.displayName, systemImage: statusIcon(status).name)
                }
            }
        } label: {
            Image(systemName: statusIcon(effective).name)
                .foregroundStyle(statusIcon(effective).color)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(task.hasSubtasks)
        .accessibilityLabel(task.hasSubtasks
            ? "状态由子任务计算：\(effective.displayName)"
            : "切换状态，当前\(effective.displayName)")
    }

    /// 进度任务：数值 + 进度条 + 步进器（有子任务时只读，进度由子任务汇总）
    private var progressControl: some View {
        let progress = ProgressEngine.effectiveProgress(of: task)
        return HStack(spacing: 8) {
            Text("\(Int(progress.current))/\(Int(progress.total))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            ProgressView(value: progress.total > 0 ? progress.current / progress.total : 0)
                .frame(width: 60)
                .animation(reduceMotion ? nil : .easeInOut, value: progress.current)
            if !task.hasSubtasks {
                // 手动调整（接管时 Stepper 只读，显示汇总值）
                Stepper(
                    value: Binding(
                        get: { task.currentAmount },
                        set: { newValue in
                            task.setProgress(newValue)
                            persistAndBackup()
                        }
                    ),
                    in: 0...max(task.totalAmount, 1)
                ) {
                    EmptyView()
                }
                .labelsHidden()
                .accessibilityLabel("调整进度")
            }
        }
    }

    // MARK: - 辅助

    /// 展开/折叠绑定（带动画，遵循减弱动态效果）
    private var expansionBinding: Binding<Bool> {
        Binding(
            get: { expandedState.expandedIDs.contains(task.id) },
            set: { expanded in
                withAnimation(reduceMotion ? nil : .easeInOut) {
                    if expanded {
                        expandedState.expandedIDs.insert(task.id)
                    } else {
                        expandedState.expandedIDs.remove(task.id)
                    }
                }
            }
        )
    }

    /// 子任务排序
    private var sortedSubtasks: [TaskItem] {
        task.subtasks.sorted {
            $0.sortOrder != $1.sortOrder ? $0.sortOrder < $1.sortOrder : $0.createdAt < $1.createdAt
        }
    }

    /// 任务的直接父级任务为一时一级任务时回退取目标
    private var parentGoalFallback: Goal {
        task.parentTask?.goal ?? task.goal ?? Goal()
    }

    /// 状态图标（名称 + 颜色）
    private func statusIcon(_ status: TaskStatus) -> (name: String, color: Color) {
        switch status {
        case .notDone: return ("circle", .secondary)
        case .halfDone: return ("circle.lefthalf.filled", .orange)
        case .done: return ("circle.fill", .green)
        case .deleted: return ("trash", .red)
        }
    }

    /// 无障碍描述：任务名 + 状态/进度
    private var accessibilityDescription: String {
        if task.type == .single {
            let effective = ProgressEngine.effectiveStatus(of: task)
            return "\(task.name)，\(effective.displayName)"
        }
        let progress = ProgressEngine.effectiveProgress(of: task)
        return "\(task.name)，进度 \(Int(progress.current)) / \(Int(progress.total))"
    }

    /// 持久化并同步 Keychain 备份
    private func persistAndBackup() {
        try? context.save()
        DataBackupManager.shared.backupAppData(context: context)
    }

    /// 级联删除：取消通知 → 删除（后代一并删除）→ 备份
    private func deleteTask() {
        NotificationService.shared.cancelReminders(taskID: task.id)
        context.delete(task)
        try? context.save()
        DataBackupManager.shared.backupAppData(context: context)
    }
}
