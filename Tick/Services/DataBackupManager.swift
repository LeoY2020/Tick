import Foundation
import SwiftData
import Combine

// MARK: - 快照 DTO（Codable）

/// 应用数据快照：全部目标与任务（含嵌套树）
struct AppDataSnapshot: Codable {
    /// 快照格式版本（供未来迁移）
    var version: Int
    var goals: [GoalDTO]
}

/// 目标快照
struct GoalDTO: Codable {
    var id: UUID
    var name: String
    var colorHex: String
    var iconSystemName: String?
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date
    /// 一级任务（更深层的子任务嵌套在 TaskDTO.subtasks）
    var tasks: [TaskDTO]
}

/// 任务快照（subtasks 递归嵌套，支持无限层级）
struct TaskDTO: Codable {
    var id: UUID
    var name: String
    var colorHex: String?
    var iconSystemName: String?
    var typeRaw: String
    var statusRaw: String
    var totalAmount: Double
    var currentAmount: Double
    var startDate: Date?
    var endDate: Date?
    var reminderDate: Date?
    var repeatRuleRaw: String?
    var customWeekdaysRaw: String?
    var createdAt: Date
    var sortOrder: Int
    var subtasks: [TaskDTO]
}

/// 用户设置快照（字段全有默认值）
struct SettingsSnapshot: Codable {
    /// 配色方案原始值（跟随系统 = "system"）
    var colorSchemeRaw: String
    /// 语言原始值（跟随系统 = "system"）
    var languageRaw: String
    /// iCloud 同步开关（同时作为"曾开启同步"的恢复标记）
    var iCloudSyncEnabled: Bool

    init(colorSchemeRaw: String = "system",
         languageRaw: String = "system",
         iCloudSyncEnabled: Bool = false) {
        self.colorSchemeRaw = colorSchemeRaw
        self.languageRaw = languageRaw
        self.iCloudSyncEnabled = iCloudSyncEnabled
    }
}

// MARK: - 备份状态

/// 备份状态（设置界面展示：成功 / 空间不足 / 失败）
enum BackupStatus: Equatable {
    case idle
    case success(Date)
    case failed(String)
    case insufficientSpace
}

// MARK: - 数据备份管理器

/// 数据备份管理器：数据变更时同步备份至 Keychain；首次启动空库时恢复。
/// 所有公开方法不抛出（内部 catch），保证 UI 调用安全。
@MainActor
final class DataBackupManager: ObservableObject {
    static let shared = DataBackupManager()

    /// 当前备份状态（设置界面展示）
    @Published private(set) var status: BackupStatus = .idle
    /// 恢复中（UI 显示 ProgressView circular）
    @Published private(set) var isRestoring = false

    private let keychain = KeychainBackupService.shared
    /// 约 1MB 软阈值：超过后仍尝试写入，由 Keychain 硬阈值与设备实际限制决定成败
    private let snapshotLimitBytes = 1_000_000
    /// 快照格式版本
    private let snapshotVersion = 1

    private init() {}

    // MARK: - 备份

    /// 序列化全部目标与任务（含嵌套树）→ JSON → Keychain appData
    func backupAppData(context: ModelContext) {
        guard let snapshot = makeSnapshot(context: context) else {
            status = .failed("无法构建数据快照")
            return
        }
        do {
            let data = try JSONEncoder().encode(snapshot)
            // 容量降级：输出超过 snapshotLimitBytes 软阈值时仍尝试写入，
            // Keychain 实际容量约 512KB~数 MB（视设备而定），写入结果决定最终状态
            try keychain.saveAppData(data)
            status = .success(Date())
        } catch BackupError.insufficientSpace {
            status = .insufficientSpace
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// 设置快照 → Keychain settings。
    /// 成功不覆盖 status（status 反映应用数据备份状态，避免掩盖空间不足提示）；失败仍需上报。
    func backupSettings(_ snapshot: SettingsSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try keychain.saveSettings(data)
        } catch BackupError.insufficientSpace {
            status = .insufficientSpace
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - 恢复

    /// 首次启动空库检测与恢复：
    /// Goal 数为 0 且 Keychain 有快照 → 解码插入并返回 true；恢复期间 isRestoring = true。
    /// 备份损坏（解码失败）视为无备份，走正常首启流程。
    func restoreIfNeeded(context: ModelContext) -> Bool {
        do {
            // 本地库非空（已有目标）→ 无需恢复
            guard try context.fetchCount(FetchDescriptor<Goal>()) == 0 else { return false }
            // Keychain 无备份 → 正常首次使用
            guard let data = keychain.loadAppData() else { return false }

            isRestoring = true
            defer { isRestoring = false }
            let snapshot = try JSONDecoder().decode(AppDataSnapshot.self, from: data)
            restore(snapshot: snapshot, into: context)
            return true
        } catch {
            return false
        }
    }

    /// 将快照恢复到 context（供手动恢复/测试）：按 GoalDTO 重建 Goal，
    /// 逐层创建 TaskItem 并 attach（一级任务挂 goal，子任务挂 parentTask），保持 sortOrder
    func restore(snapshot: AppDataSnapshot, into context: ModelContext) {
        for goalDTO in snapshot.goals {
            let goal = Goal(name: goalDTO.name,
                            colorHex: goalDTO.colorHex,
                            iconSystemName: goalDTO.iconSystemName,
                            startDate: goalDTO.startDate,
                            endDate: goalDTO.endDate)
            goal.id = goalDTO.id
            goal.createdAt = goalDTO.createdAt
            context.insert(goal)

            for taskDTO in goalDTO.tasks {
                restoreTask(taskDTO, into: context, parent: nil, goal: goal)
            }
        }
        try? context.save()
    }

    /// 从 context 构建快照：fetch 全部 Goal 与 TaskItem，按 parentTask 重建树，
    /// 一级任务（parentTask == nil）挂到对应 GoalDTO，子任务递归嵌套，按 sortOrder 排序
    func makeSnapshot(context: ModelContext) -> AppDataSnapshot? {
        do {
            let goals = try context.fetch(FetchDescriptor<Goal>())
            let tasks = try context.fetch(FetchDescriptor<TaskItem>())

            // 一级任务按所属 goal.id 分组
            var topLevelTasks: [UUID: [TaskItem]] = [:]
            for task in tasks where task.parentTask == nil {
                guard let goalID = task.goal?.id else { continue } // 孤儿任务跳过
                topLevelTasks[goalID, default: []].append(task)
            }

            let goalDTOs = goals.map { goal in
                GoalDTO(id: goal.id,
                        name: goal.name,
                        colorHex: goal.colorHex,
                        iconSystemName: goal.iconSystemName,
                        startDate: goal.startDate,
                        endDate: goal.endDate,
                        createdAt: goal.createdAt,
                        tasks: sortedByOrder(topLevelTasks[goal.id] ?? []).map(makeTaskDTO))
            }
            return AppDataSnapshot(version: snapshotVersion, goals: goalDTOs)
        } catch {
            return nil
        }
    }

    /// 读取设置快照
    func loadSettingsSnapshot() -> SettingsSnapshot? {
        guard let data = keychain.loadSettings() else { return nil }
        return try? JSONDecoder().decode(SettingsSnapshot.self, from: data)
    }

    /// iCloud 曾开启标记（spec 恢复流程第 2 步）：从 settings 快照判断
    func iCloudSyncWasEnabled() -> Bool {
        loadSettingsSnapshot()?.iCloudSyncEnabled == true
    }
}

// MARK: - 私有辅助

private extension DataBackupManager {

    /// 按（sortOrder, createdAt）稳定排序
    func sortedByOrder(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    /// TaskItem → TaskDTO（子任务递归嵌套）
    func makeTaskDTO(_ task: TaskItem) -> TaskDTO {
        TaskDTO(id: task.id,
                name: task.name,
                colorHex: task.colorHex,
                iconSystemName: task.iconSystemName,
                typeRaw: task.typeRaw,
                statusRaw: task.statusRaw,
                totalAmount: task.totalAmount,
                currentAmount: task.currentAmount,
                startDate: task.startDate,
                endDate: task.endDate,
                reminderDate: task.reminderDate,
                repeatRuleRaw: task.repeatRuleRaw,
                customWeekdaysRaw: task.customWeekdaysRaw,
                createdAt: task.createdAt,
                sortOrder: task.sortOrder,
                subtasks: sortedByOrder(task.subtasks).map(makeTaskDTO))
    }

    /// TaskDTO → TaskItem 逐层重建（一级任务挂 goal，子任务挂 parentTask）
    func restoreTask(_ dto: TaskDTO, into context: ModelContext, parent: TaskItem?, goal: Goal?) {
        let task = TaskItem(name: dto.name,
                            type: TaskType(rawValue: dto.typeRaw) ?? .single,
                            colorHex: dto.colorHex,
                            iconSystemName: dto.iconSystemName,
                            status: TaskStatus(rawValue: dto.statusRaw) ?? .notDone,
                            totalAmount: dto.totalAmount,
                            currentAmount: dto.currentAmount,
                            startDate: dto.startDate,
                            endDate: dto.endDate,
                            reminderDate: dto.reminderDate,
                            repeatRule: dto.repeatRuleRaw.flatMap { RepeatRule(rawValue: $0) },
                            customWeekdaysRaw: dto.customWeekdaysRaw,
                            sortOrder: dto.sortOrder)
        task.id = dto.id
        task.createdAt = dto.createdAt
        context.insert(task)

        if let parent {
            task.attach(to: parent)
        } else if let goal {
            task.attach(to: goal)
        }
        for subDTO in dto.subtasks {
            restoreTask(subDTO, into: context, parent: task, goal: nil)
        }
    }
}
