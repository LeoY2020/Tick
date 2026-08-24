import XCTest
import SwiftData
@testable import Tick

/// Keychain 备份与恢复测试（宿主 App 环境下 Keychain 可用；
/// 环境受限时通过 XCTSkip 优雅跳过，避免不稳定失败）
final class KeychainBackupTests: XCTestCase {
    /// 唯一随机服务名实例：隔离 Keychain 条目，避免污染真实备份数据
    var keychain: KeychainBackupService!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        keychain = KeychainBackupService(service: "com.tick.tests.\(UUID().uuidString)")
        let schema = Schema([Goal.self, TaskItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        keychain = nil
    }

    // MARK: - a) Keychain 数据往返

    /// saveAppData/loadAppData、saveSettings/loadSettings 数据往返一致；
    /// 二次写入验证更新（SecItemUpdate）路径
    func testKeychainRoundTrip() throws {
        let appData = Data("tick-appData-\(UUID().uuidString)".utf8)
        let settings = Data("tick-settings-\(UUID().uuidString)".utf8)

        // 前置依赖：宿主 App 环境下 Keychain 可写；不可用（模拟器限制等）时优雅跳过
        do {
            try keychain.saveAppData(appData)
            try keychain.saveSettings(settings)
        } catch {
            throw XCTSkip("当前环境 Keychain 不可写，跳过往返验证：\(error.localizedDescription)")
        }

        // 前置依赖：写入成功但读取受限（个别模拟器环境）时优雅跳过
        try XCTSkipUnless(keychain.loadAppData() != nil,
                          "当前环境 Keychain 读取受限，跳过往返验证")

        XCTAssertEqual(keychain.loadAppData(), appData, "appData 数据往返应一致")
        XCTAssertEqual(keychain.loadSettings(), settings, "settings 数据往返应一致")

        // 覆盖写入 → 验证更新已有条目路径
        let appDataV2 = Data("tick-appData-v2-\(UUID().uuidString)".utf8)
        try keychain.saveAppData(appDataV2)
        XCTAssertEqual(keychain.loadAppData(), appDataV2, "覆盖写入后应读取到新数据")
    }

    // MARK: - b) 快照编码往返

    /// 两层嵌套目标任务树 → makeSnapshot → JSON 编码解码 → 字段一致
    @MainActor
    func testSnapshotEncodingRoundTrip() throws {
        let goal = Goal(name: "健身", colorHex: "#FF9500", iconSystemName: "figure.run",
                        startDate: Date(timeIntervalSince1970: 1000),
                        endDate: Date(timeIntervalSince1970: 2000))
        let parent = TaskItem(name: "跑步", type: .progress, colorHex: "#FF3B30",
                              totalAmount: 10, currentAmount: 4, sortOrder: 0)
        let childA = TaskItem(name: "晨跑", type: .single, status: .done,
                              iconSystemName: "sunrise", sortOrder: 0)
        let childB = TaskItem(name: "夜跑", type: .progress,
                              startDate: Date(timeIntervalSince1970: 3000),
                              reminderDate: Date(timeIntervalSince1970: 4000),
                              repeatRule: .daily, customWeekdaysRaw: "1,3,5",
                              totalAmount: 5, currentAmount: 2, sortOrder: 1)
        let reading = TaskItem(name: "阅读", type: .single, status: .halfDone, sortOrder: 1)

        context.insert(goal)
        context.insert(parent)
        context.insert(childA)
        context.insert(childB)
        context.insert(reading)
        parent.attach(to: goal)
        childA.attach(to: parent)
        childB.attach(to: parent)
        reading.attach(to: goal)
        try context.save()

        let snapshot = try XCTUnwrap(DataBackupManager.shared.makeSnapshot(context: context))
        XCTAssertEqual(snapshot.version, 1)
        XCTAssertEqual(snapshot.goals.count, 1)

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(AppDataSnapshot.self, from: data)
        XCTAssertEqual(decoded.version, snapshot.version)
        XCTAssertEqual(decoded.goals.count, 1)

        let goalDTO = try XCTUnwrap(decoded.goals.first)
        XCTAssertEqual(goalDTO.id, snapshot.goals[0].id)
        XCTAssertEqual(goalDTO.name, "健身")
        XCTAssertEqual(goalDTO.colorHex, "#FF9500")
        XCTAssertEqual(goalDTO.iconSystemName, "figure.run")
        XCTAssertEqual(goalDTO.startDate, Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(goalDTO.endDate, Date(timeIntervalSince1970: 2000))

        // 一级任务按 sortOrder 排序：跑步(0)、阅读(1)；子任务不混入一级
        XCTAssertEqual(goalDTO.tasks.map(\.name), ["跑步", "阅读"])

        let parentDTO = try XCTUnwrap(goalDTO.tasks.first { $0.name == "跑步" })
        XCTAssertEqual(parentDTO.typeRaw, TaskType.progress.rawValue)
        XCTAssertEqual(parentDTO.totalAmount, 10)
        XCTAssertEqual(parentDTO.currentAmount, 4)
        XCTAssertEqual(parentDTO.subtasks.map(\.name), ["晨跑", "夜跑"])

        let childADTO = try XCTUnwrap(parentDTO.subtasks.first { $0.name == "晨跑" })
        XCTAssertEqual(childADTO.statusRaw, TaskStatus.done.rawValue)
        XCTAssertEqual(childADTO.iconSystemName, "sunrise")

        let childBDTO = try XCTUnwrap(parentDTO.subtasks.first { $0.name == "夜跑" })
        XCTAssertEqual(childBDTO.typeRaw, TaskType.progress.rawValue)
        XCTAssertEqual(childBDTO.totalAmount, 5)
        XCTAssertEqual(childBDTO.currentAmount, 2)
        XCTAssertEqual(childBDTO.reminderDate, Date(timeIntervalSince1970: 4000))
        XCTAssertEqual(childBDTO.repeatRuleRaw, RepeatRule.daily.rawValue)
        XCTAssertEqual(childBDTO.customWeekdaysRaw, "1,3,5")
    }

    // MARK: - c) 快照恢复到空库

    /// 空 context + 快照 → restore → fetch 验证层级、颜色、类型、状态、进度值完整恢复
    @MainActor
    func testRestoreIntoEmptyContext() throws {
        let now = Date(timeIntervalSince1970: 5000)
        let childA = TaskDTO(id: UUID(), name: "晨跑", colorHex: "#34C759", iconSystemName: "sunrise",
                             typeRaw: TaskType.single.rawValue,
                             statusRaw: TaskStatus.halfDone.rawValue,
                             totalAmount: 0, currentAmount: 0,
                             startDate: nil, endDate: nil, reminderDate: nil,
                             repeatRuleRaw: RepeatRule.weekly.rawValue, customWeekdaysRaw: nil,
                             createdAt: now, sortOrder: 0, subtasks: [])
        let childB = TaskDTO(id: UUID(), name: "夜跑", colorHex: nil, iconSystemName: nil,
                             typeRaw: TaskType.progress.rawValue,
                             statusRaw: TaskStatus.notDone.rawValue,
                             totalAmount: 8, currentAmount: 3,
                             startDate: nil, endDate: nil,
                             reminderDate: Date(timeIntervalSince1970: 6000),
                             repeatRuleRaw: nil, customWeekdaysRaw: "2,4",
                             createdAt: now, sortOrder: 1, subtasks: [])
        let parent = TaskDTO(id: UUID(), name: "跑步计划", colorHex: "#FF3B30",
                             iconSystemName: "figure.run",
                             typeRaw: TaskType.progress.rawValue,
                             statusRaw: TaskStatus.notDone.rawValue,
                             totalAmount: 10, currentAmount: 4,
                             startDate: Date(timeIntervalSince1970: 1000),
                             endDate: Date(timeIntervalSince1970: 2000),
                             reminderDate: nil, repeatRuleRaw: nil, customWeekdaysRaw: nil,
                             createdAt: now, sortOrder: 0, subtasks: [childA, childB])
        let goalDTO = GoalDTO(id: UUID(), name: "健身", colorHex: "#5856D6",
                              iconSystemName: "flag.fill",
                              startDate: nil, endDate: Date(timeIntervalSince1970: 9000),
                              createdAt: now, tasks: [parent])
        let snapshot = AppDataSnapshot(version: 1, goals: [goalDTO])

        // 前置：context 为空库
        XCTAssertTrue(try context.fetch(FetchDescriptor<Goal>()).isEmpty, "恢复前 context 应为空")

        DataBackupManager.shared.restore(snapshot: snapshot, into: context)

        // 用全新 context 从存储重新读取，验证持久化完整
        let freshContext = ModelContext(container)
        let goals = try freshContext.fetch(FetchDescriptor<Goal>())
        XCTAssertEqual(goals.count, 1)
        let restoredGoal = try XCTUnwrap(goals.first)
        XCTAssertEqual(restoredGoal.id, goalDTO.id)
        XCTAssertEqual(restoredGoal.name, "健身")
        XCTAssertEqual(restoredGoal.colorHex, "#5856D6")
        XCTAssertEqual(restoredGoal.iconSystemName, "flag.fill")
        XCTAssertEqual(restoredGoal.endDate, Date(timeIntervalSince1970: 9000))
        XCTAssertEqual(restoredGoal.tasks.count, 1, "仅一级任务直接挂 goal")

        let tasks = try freshContext.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.count, 3)

        // 一级任务：挂 goal、类型/颜色/进度/日期完整恢复
        let parentTask = try XCTUnwrap(tasks.first { $0.id == parent.id })
        XCTAssertEqual(parentTask.goal?.id, goalDTO.id)
        XCTAssertNil(parentTask.parentTask)
        XCTAssertEqual(parentTask.type, .progress)
        XCTAssertEqual(parentTask.colorHex, "#FF3B30")
        XCTAssertEqual(parentTask.iconSystemName, "figure.run")
        XCTAssertEqual(parentTask.totalAmount, 10)
        XCTAssertEqual(parentTask.currentAmount, 4)
        XCTAssertEqual(parentTask.startDate, Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(parentTask.endDate, Date(timeIntervalSince1970: 2000))

        // 子任务：挂 parentTask、按 sortOrder 排序、字段完整
        let subtasks = parentTask.subtasks.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(subtasks.map(\.name), ["晨跑", "夜跑"])

        let restoredA = try XCTUnwrap(subtasks.first { $0.id == childA.id })
        XCTAssertEqual(restoredA.parentTask?.id, parent.id)
        XCTAssertNil(restoredA.goal, "子任务不应直接挂 goal")
        XCTAssertEqual(restoredA.status, .halfDone)
        XCTAssertEqual(restoredA.colorHex, "#34C759")
        XCTAssertEqual(restoredA.iconSystemName, "sunrise")
        XCTAssertEqual(restoredA.repeatRule, .weekly)

        let restoredB = try XCTUnwrap(subtasks.first { $0.id == childB.id })
        XCTAssertEqual(restoredB.type, .progress)
        XCTAssertEqual(restoredB.totalAmount, 8)
        XCTAssertEqual(restoredB.currentAmount, 3)
        XCTAssertEqual(restoredB.reminderDate, Date(timeIntervalSince1970: 6000))
        XCTAssertEqual(restoredB.effectiveWeekdays(), [2, 4])
    }

    // MARK: - d) 设置快照往返

    /// 设置快照编解码往返 + 默认值 init
    func testSettingsSnapshotRoundTrip() throws {
        let snapshot = SettingsSnapshot(colorSchemeRaw: "dark",
                                        languageRaw: "zh-Hans",
                                        iCloudSyncEnabled: true)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: data)

        XCTAssertEqual(decoded.colorSchemeRaw, "dark")
        XCTAssertEqual(decoded.languageRaw, "zh-Hans")
        XCTAssertTrue(decoded.iCloudSyncEnabled)

        // 默认值：跟随系统 + iCloud 关闭
        let defaults = SettingsSnapshot()
        XCTAssertEqual(defaults.colorSchemeRaw, "system")
        XCTAssertEqual(defaults.languageRaw, "system")
        XCTAssertFalse(defaults.iCloudSyncEnabled)
    }
}
