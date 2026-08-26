import SwiftUI
import SwiftData

/// 快速添加任务表单：一级任务（parent = nil）或子任务
struct QuickAddTaskView: View {
    /// 归属目标
    let goal: Goal
    /// 父任务（nil = 一级任务）
    let parent: TaskItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var type: TaskType = .single
    @State private var totalText = ""

    /// 进度总量是否合法（正整数）
    private var validTotal: Bool {
        guard type == .progress else { return true }
        guard let total = Int(totalText) else { return false }
        return total > 0
    }

    /// 保存是否可用：名称非空 + 总量合法
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && validTotal
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("新任务") {
                    TextField("名称", text: $name)
                        .accessibilityLabel("任务名称")
                    Picker("类型", selection: $type) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("任务类型")
                }
                if type == .progress {
                    Section("进度") {
                        TextField("总量", text: $totalText)
                            .keyboardType(.numberPad)
                            .accessibilityLabel("进度总量")
                    }
                }
            }
            .navigationTitle(parent == nil ? "添加任务" : "添加子任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .accessibilityLabel("取消")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!canSave)
                        .accessibilityLabel("保存任务")
                }
            }
        }
    }

    // MARK: - 保存

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, validTotal else { return }

        let total = type == .progress ? Double(Int(totalText) ?? 0) : 0
        let task = TaskItem(name: trimmed, type: type, totalAmount: total)
        context.insert(task)

        // 挂接：一级任务 → 目标；否则 → 父任务
        if let parent {
            task.attach(to: parent)
        } else {
            task.attach(to: goal)
        }

        // 排序值：现有兄弟任务最大 sortOrder + 1
        let siblings = parent?.subtasks ?? goal.tasks
        task.sortOrder = (siblings.map(\.sortOrder).max() ?? -1) + 1

        try? context.save()
        // 数据变更 → 同步 Keychain 备份
        DataBackupManager.shared.backupAppData(context: context)
        dismiss()
    }
}
