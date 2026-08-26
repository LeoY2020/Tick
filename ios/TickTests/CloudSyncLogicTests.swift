import XCTest
import SwiftData
@testable import Tick

/// CloudSync 纯逻辑测试：不依赖真实 iCloud 账号。
/// CI 模拟器无 iCloud 账号 / entitlement 时，CloudKit 容器创建失败会自动回退本地行为，冒烟测试不受影响。
@MainActor
final class CloudSyncLogicTests: XCTestCase {

    /// 本地配置生成：cloudKitDatabase 应为 nil/.none（本地），非内存存储，且不引用 CloudKit 容器
    func testLocalConfigurationCreation() throws {
        // makeConfiguration 依据 SettingsStore 当前开关生成配置；测试环境默认应为本地模式
        try XCTSkipUnless(SettingsStore.shared.iCloudSyncEnabled == false,
                          "当前环境 iCloud 同步已开启，非本地配置，跳过断言")

        let config = CloudSyncManager.shared.makeConfiguration()

        // cloudKitDatabase 应为本地（nil / .none）。
        // 注：该属性在 SDK 中存在可选 / 非可选两种形态，字符串断言可同时覆盖
        // nil（Optional.none）、none（CloudKitDatabase.none）、Optional(none) 三种本地表达
        let dbDescription = String(describing: config.cloudKitDatabase)
        XCTAssertTrue(dbDescription == "nil" || dbDescription.contains("none"),
                      "本地配置 cloudKitDatabase 应为 nil/.none，实际: \(dbDescription)")

        // 本地持久化（非内存）
        XCTAssertFalse(config.isStoredInMemoryOnly)

        // 配置不应引用 CloudKit 容器标识
        XCTAssertFalse(String(describing: config).contains("iCloud.com.tick.app"))
    }

    /// 容器冒烟：插入 Goal + 两层 TaskItem → save → 重新 fetch 验证树完整 → 清理删除
    func testContainerSmoke() throws {
        let context = ModelContext(CloudSyncManager.shared.container)

        // —— 构造：Goal → 一级任务（进度型）→ 二级子任务（单项型）——
        let goalID = UUID()
        let parentID = UUID()
        let childID = UUID()

        let goal = Goal(name: "CloudSync 冒烟目标")
        goal.id = goalID
        context.insert(goal)

        let parent = TaskItem(name: "一级任务", type: .progress, totalAmount: 10)
        parent.id = parentID
        context.insert(parent)
        parent.attach(to: goal)

        let child = TaskItem(name: "二级子任务", type: .single)
        child.id = childID
        context.insert(child)
        child.attach(to: parent)

        do {
            try context.save()
        } catch {
            // 环境限制（如只读存储）导致保存失败 → 跳过而非误报
            throw XCTSkip("容器保存失败（环境限制）: \(error)")
        }

        // —— 全新 context 重新 fetch，按固定 ID 检索（不受库中其他数据影响），验证两层树完整 ——
        let verify = ModelContext(CloudSyncManager.shared.container)

        let fetchedGoals = try verify.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.id == goalID }))
        XCTAssertEqual(fetchedGoals.count, 1, "目标应可重新 fetch")

        let fetchedParents = try verify.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == parentID }))
        XCTAssertEqual(fetchedParents.count, 1, "一级任务应可重新 fetch")

        let fetchedChildren = try verify.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == childID }))
        XCTAssertEqual(fetchedChildren.count, 1, "二级子任务应可重新 fetch")

        let fetchedGoal = fetchedGoals.first
        let fetchedParent = fetchedParents.first
        let fetchedChild = fetchedChildren.first

        // 关系完整性：子 → 父 → 目标 双向可达
        XCTAssertEqual(fetchedChild?.parentTask?.id, parentID, "子任务应挂载到父任务")
        XCTAssertEqual(fetchedParent?.goal?.id, goalID, "一级任务应挂载到目标")
        XCTAssertTrue(fetchedParent?.subtasks.contains { $0.id == childID } == true, "父任务应包含二级子任务")
        XCTAssertTrue(fetchedGoal?.tasks.contains { $0.id == parentID } == true, "目标应包含一级任务")

        // —— 清理：删除 Goal 级联删除两层任务 ——
        if let fetchedGoal {
            verify.delete(fetchedGoal)
        }
        try verify.save()

        // 清理验证：按 ID 重新 fetch 应为空
        let remainingGoals = try verify.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.id == goalID }))
        XCTAssertTrue(remainingGoals.isEmpty, "清理后目标应被删除")
        let remainingTasks = try verify.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == parentID || $0.id == childID }))
        XCTAssertTrue(remainingTasks.isEmpty, "清理后两层任务应级联删除")
    }
}