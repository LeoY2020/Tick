import XCTest
import SwiftData
@testable import Tick

/// 递归进度计算引擎测试（内存容器，每个用例独立 context）
final class ProgressEngineTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Goal.self, TaskItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - 辅助

    /// 插入并作为一级任务挂到目标
    @discardableResult
    private func insert(_ task: TaskItem, into goal: Goal) -> TaskItem {
        context.insert(task)
        task.attach(to: goal)
        return task
    }

    /// 插入并作为子任务挂到父任务
    @discardableResult
    private func insert(_ task: TaskItem, under parent: TaskItem) -> TaskItem {
        context.insert(task)
        task.attach(to: parent)
        return task
    }

    // MARK: - a) 空目标

    /// 空目标 → fraction 为 0
    func testEmptyGoalFractionIsZero() throws {
        let goal = Goal(name: "空目标")
        context.insert(goal)
        try context.save()

        let progress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(progress.totalItems, 0)
        XCTAssertEqual(progress.completedWeight, 0)
        XCTAssertEqual(progress.fraction, 0)
    }

    // MARK: - b) 单项四态折算

    /// 单项四态：done=1、halfDone=0.5、notDone=0、deleted 不计入 totalItems
    func testSingleStatusWeightsAndDeletedExcluded() throws {
        let goal = Goal(name: "目标")
        context.insert(goal)
        insert(TaskItem(name: "完成", status: .done), into: goal)
        insert(TaskItem(name: "半完成", status: .halfDone), into: goal)
        insert(TaskItem(name: "未完成", status: .notDone), into: goal)
        insert(TaskItem(name: "删除", status: .deleted), into: goal)
        try context.save()

        let progress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(progress.totalItems, 3, "删除态不计入总量")
        XCTAssertEqual(progress.completedWeight, 1.5, accuracy: 0.000001)
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.000001)
    }

    // MARK: - c) 进度叶子比率与 clamp

    /// 进度叶子：比率折算；current > total 时 clamp 后按比率计算；total ≤ 0 时比率为 0
    func testProgressLeafRatioAndClamp() throws {
        let goal = Goal(name: "目标")
        context.insert(goal)
        insert(TaskItem(name: "半程", type: .progress, totalAmount: 10, currentAmount: 5), into: goal)
        let over = insert(TaskItem(name: "超量", type: .progress, totalAmount: 10), into: goal)
        over.currentAmount = 15 // 绕过 setProgress 直接赋值，验证引擎侧 clamp
        let zeroTotal = insert(TaskItem(name: "零总量", type: .progress, totalAmount: 0, currentAmount: 0), into: goal)
        try context.save()

        // current > total：clamp 到 total，比率按 1 计算
        let overProgress = ProgressEngine.effectiveProgress(of: over)
        XCTAssertEqual(overProgress.current, 10)
        XCTAssertEqual(overProgress.total, 10)

        // total ≤ 0：比率为 0
        let zeroProgress = ProgressEngine.effectiveProgress(of: zeroTotal)
        XCTAssertEqual(zeroProgress.current, 0)
        XCTAssertEqual(zeroProgress.total, 0)

        // 目标权重：0.5（半程）+ 1（超量 clamp）+ 0（零总量）= 1.5 / 3
        let progress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(progress.totalItems, 3)
        XCTAssertEqual(progress.completedWeight, 1.5, accuracy: 0.000001)
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.000001)
    }

    // MARK: - d) 单项父任务接管

    /// 单项父任务接管：全 done→done、全 notDone→notDone、混合/含半完成→halfDone；删除态子任务被跳过
    func testSingleParentTakeoverStatusFolding() throws {
        let goal = Goal(name: "目标")
        context.insert(goal)

        let allDone = insert(TaskItem(name: "全完成父"), into: goal)
        insert(TaskItem(name: "子1", status: .done), under: allDone)
        insert(TaskItem(name: "子2", status: .done), under: allDone)

        let allNotDone = insert(TaskItem(name: "全未完成父"), into: goal)
        insert(TaskItem(name: "子1", status: .notDone), under: allNotDone)
        insert(TaskItem(name: "子2", status: .notDone), under: allNotDone)

        let mixed = insert(TaskItem(name: "混合父"), into: goal)
        insert(TaskItem(name: "子1", status: .done), under: mixed)
        insert(TaskItem(name: "子2", status: .notDone), under: mixed)

        let withHalf = insert(TaskItem(name: "含半完成父"), into: goal)
        insert(TaskItem(name: "子1", status: .notDone), under: withHalf)
        insert(TaskItem(name: "子2", status: .halfDone), under: withHalf)

        let withDeleted = insert(TaskItem(name: "含删除父"), into: goal)
        insert(TaskItem(name: "子1", status: .done), under: withDeleted)
        insert(TaskItem(name: "子2", status: .deleted), under: withDeleted)
        try context.save()

        XCTAssertEqual(ProgressEngine.effectiveStatus(of: allDone), .done, "全部子任务完成 → 完成")
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: allNotDone), .notDone, "全部子任务未完成 → 未完成")
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: mixed), .halfDone, "完成与未完成混合 → 半完成")
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: withHalf), .halfDone, "存在半完成子任务 → 半完成")
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: withDeleted), .done, "删除态子任务被跳过，剩余全完成 → 完成")

        // 删除态子任务同样不计入进度汇总：仅 done 子任务贡献 (1, 1)
        let progress = ProgressEngine.effectiveProgress(of: withDeleted)
        XCTAssertEqual(progress.current, 1)
        XCTAssertEqual(progress.total, 1)
    }

    /// 进度子任务按有效比率折算为状态：1→完成、0<比率<1→半完成、0→未完成
    func testProgressChildRatioFoldsStatus() throws {
        let goal = Goal(name: "目标")
        context.insert(goal)

        let full = insert(TaskItem(name: "满进度父"), into: goal)
        insert(TaskItem(name: "满", type: .progress, totalAmount: 4, currentAmount: 4), under: full)
        let partial = insert(TaskItem(name: "半进度父"), into: goal)
        insert(TaskItem(name: "半", type: .progress, totalAmount: 4, currentAmount: 2), under: partial)
        let empty = insert(TaskItem(name: "零进度父"), into: goal)
        insert(TaskItem(name: "零", type: .progress, totalAmount: 4, currentAmount: 0), under: empty)
        try context.save()

        XCTAssertEqual(ProgressEngine.effectiveStatus(of: full), .done, "比率=1 视为完成")
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: partial), .halfDone, "0<比率<1 视为半完成")
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: empty), .notDone, "比率=0 视为未完成")
    }

    // MARK: - e) 进度父任务接管

    /// 进度父任务接管：总量=子任务总量之和（忽略父手动总量 10，6+9→15）；当前=子任务当前之和
    func testProgressParentTakeoverIgnoresManualTotal() throws {
        let goal = Goal(name: "目标")
        context.insert(goal)
        let parent = insert(TaskItem(name: "父", type: .progress, totalAmount: 10, currentAmount: 7), into: goal)
        insert(TaskItem(name: "子1", type: .progress, totalAmount: 6, currentAmount: 3), under: parent)
        insert(TaskItem(name: "子2", type: .progress, totalAmount: 9, currentAmount: 4.5), under: parent)
        try context.save()

        let progress = ProgressEngine.effectiveProgress(of: parent)
        XCTAssertEqual(progress.total, 15, "总量=子任务总量之和，忽略父手动总量")
        XCTAssertEqual(progress.current, 7.5, accuracy: 0.000001, "当前=子任务当前之和")

        // 目标进度（默认全部任务模式）：父(0.5) + 子1(3/6=0.5) + 子2(4.5/9=0.5) = 1.5 / 3
        let goalProgress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(goalProgress.totalItems, 3, "全部任务模式：父与子均计入")
        XCTAssertEqual(goalProgress.completedWeight, 1.5, accuracy: 0.000001)
        XCTAssertEqual(goalProgress.fraction, 0.5, accuracy: 0.000001)

        // 仅叶子任务模式：只计子1 + 子2 = 1.0 / 2
        goal.progressCountingMode = .leafTasks
        let leafProgress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(leafProgress.totalItems, 2, "仅叶子任务模式：父不计入")
        XCTAssertEqual(leafProgress.completedWeight, 1.0, accuracy: 0.000001)
        XCTAssertEqual(leafProgress.fraction, 0.5, accuracy: 0.000001)
    }

    // MARK: - f) 深层递归

    /// 三层结构：叶子值逐级向上汇总（A → B → C1/C2，A 另有单项子任务 S）
    func testDeepRecursionThreeLevels() throws {
        let goal = Goal(name: "目标")
        context.insert(goal)

        let a = insert(TaskItem(name: "A", type: .progress, totalAmount: 999), into: goal)
        let b = insert(TaskItem(name: "B", type: .progress, totalAmount: 100), under: a)
        insert(TaskItem(name: "C1", type: .progress, totalAmount: 8, currentAmount: 4), under: b)
        insert(TaskItem(name: "C2", status: .done), under: b)
        insert(TaskItem(name: "S", status: .notDone), under: a)
        try context.save()

        // B：进度子 C1(4/8) + 单项子 C2(权重1/总量1) → (5, 9)
        let bProgress = ProgressEngine.effectiveProgress(of: b)
        XCTAssertEqual(bProgress.total, 9)
        XCTAssertEqual(bProgress.current, 5)

        // A：B(5, 9) + S(0, 1) → (5, 10)
        let aProgress = ProgressEngine.effectiveProgress(of: a)
        XCTAssertEqual(aProgress.total, 10)
        XCTAssertEqual(aProgress.current, 5)

        // 状态递归：B 折算比率 5/9 → 半完成；A 的子任务混合（半完成 + 未完成）→ 半完成
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: b), .halfDone)
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: a), .halfDone)

        // 目标（默认全部任务模式）：A(0.5) + B(5/9) + C1(0.5) + C2(1) + S(0) = 41/18 ≈ 2.2778，共 5 项
        let goalProgress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(goalProgress.totalItems, 5, "全部任务模式：A/B/C1/C2/S 全部计入")
        XCTAssertEqual(goalProgress.completedWeight, 0.5 + 5.0 / 9.0 + 0.5 + 1 + 0, accuracy: 0.000001)
        XCTAssertEqual(goalProgress.fraction, (0.5 + 5.0 / 9.0 + 0.5 + 1) / 5, accuracy: 0.000001)

        // 仅叶子任务模式：只计 C1(0.5) + C2(1) + S(0) = 1.5 / 3
        goal.progressCountingMode = .leafTasks
        let leafProgress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(leafProgress.totalItems, 3, "仅叶子任务模式：A/B 中间层不计")
        XCTAssertEqual(leafProgress.completedWeight, 1.5, accuracy: 0.000001)
        XCTAssertEqual(leafProgress.fraction, 0.5, accuracy: 0.000001)
    }

    // MARK: - g) 单项子任务挂进度父任务

    /// 单项子任务挂进度父任务：按 总量=1、当前=状态权重 折算；删除态跳过
    func testSingleChildrenUnderProgressParent() throws {
        let goal = Goal(name: "目标")
        context.insert(goal)
        let parent = insert(TaskItem(name: "进度父", type: .progress, totalAmount: 100), into: goal)
        insert(TaskItem(name: "完成", status: .done), under: parent)
        insert(TaskItem(name: "半完成", status: .halfDone), under: parent)
        insert(TaskItem(name: "未完成", status: .notDone), under: parent)
        insert(TaskItem(name: "删除", status: .deleted), under: parent)
        try context.save()

        // 三个有效单项子任务各计总量 1；当前 = 1 + 0.5 + 0
        let progress = ProgressEngine.effectiveProgress(of: parent)
        XCTAssertEqual(progress.total, 3)
        XCTAssertEqual(progress.current, 1.5, accuracy: 0.000001)
    }

    // MARK: - h) 接管解除

    /// 全部子任务删除后恢复手动值（接管解除：effectiveStatus/Progress 回落到手动值）
    func testTakeoverReleaseRestoresManualValues() throws {
        let goal = Goal(name: "目标")
        context.insert(goal)

        // 进度父：手动 (3, 10)；单项父：手动 halfDone
        let progressParent = insert(TaskItem(name: "进度父", type: .progress, totalAmount: 10, currentAmount: 3), into: goal)
        let progressChild = insert(TaskItem(name: "进度子", type: .progress, totalAmount: 6, currentAmount: 2), under: progressParent)
        let singleParent = insert(TaskItem(name: "单项父", status: .halfDone), into: goal)
        let singleChild = insert(TaskItem(name: "单项子", status: .done), under: singleParent)
        try context.save()

        // 接管中：由子任务计算
        var parentProgress = ProgressEngine.effectiveProgress(of: progressParent)
        XCTAssertEqual(parentProgress.total, 6)
        XCTAssertEqual(parentProgress.current, 2)
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: singleParent), .done)

        // 子任务全部置为删除态（软删除）：spec 接管解除 → 恢复手动值
        singleChild.status = .deleted
        try context.save()
        XCTAssertEqual(ProgressEngine.effectiveStatus(of: singleParent), .halfDone, "全部子任务删除态 → 恢复手动状态")

        // subtasks 清空（硬删除子任务）：同样恢复手动值
        context.delete(progressChild)
        try context.save()
        XCTAssertFalse(progressParent.hasSubtasks)

        parentProgress = ProgressEngine.effectiveProgress(of: progressParent)
        XCTAssertEqual(parentProgress.current, 3, "恢复删除前手动当前值")
        XCTAssertEqual(parentProgress.total, 10, "恢复删除前手动总量")
    }

    // MARK: - i) 进度统计模式

    /// 全部任务模式（默认）：所有层级节点均计入总量与进度，父任务按折算权重
    func testAllTasksCountingModeCountsEveryLevel() throws {
        let goal = Goal(name: "目标")
        context.insert(goal)

        // 单项父（2 子：done + notDone → 折算 halfDone = 0.5）+ 独立叶子（done = 1）
        let parent = insert(TaskItem(name: "父"), into: goal)
        insert(TaskItem(name: "子1", status: .done), under: parent)
        insert(TaskItem(name: "子2", status: .notDone), under: parent)
        insert(TaskItem(name: "叶子", status: .done), into: goal)
        try context.save()

        XCTAssertEqual(goal.progressCountingMode, .allTasks, "默认为全部任务模式")
        let progress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(progress.totalItems, 4, "父 + 2 子 + 独立叶子均计入")
        XCTAssertEqual(progress.completedWeight, 2.5, accuracy: 0.000001, "父折算 0.5 + 子 1 + 0 + 叶子 1")
        XCTAssertEqual(progress.fraction, 0.625, accuracy: 0.000001)
    }

    /// 仅叶子任务模式：中间层不计入，只统计任务树末端节点
    func testLeafTasksCountingModeCountsOnlyLeaves() throws {
        let goal = Goal(name: "目标", progressCountingMode: .leafTasks)
        context.insert(goal)

        let parent = insert(TaskItem(name: "父"), into: goal)
        insert(TaskItem(name: "子1", status: .done), under: parent)
        insert(TaskItem(name: "子2", status: .notDone), under: parent)
        insert(TaskItem(name: "叶子", status: .done), into: goal)
        try context.save()

        let progress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(progress.totalItems, 3, "父不计入，只计 2 子 + 独立叶子")
        XCTAssertEqual(progress.completedWeight, 2, accuracy: 0.000001)
        XCTAssertEqual(progress.fraction, 2.0 / 3.0, accuracy: 0.000001)
    }

    /// 删除态处理（两种模式一致）：删除态父任务整棵子树不计入；
    /// 有效子任务全部为删除态的父任务接管解除，视为叶子按手动状态计入
    func testDeletedSubtreeExcludedInBothModes() throws {
        let goal = Goal(name: "目标", progressCountingMode: .leafTasks)
        context.insert(goal)

        // 删除态父 + 子任务（子任务虽 done，但整棵子树不计入）
        let deletedParent = insert(TaskItem(name: "删除父", status: .deleted), into: goal)
        insert(TaskItem(name: "不应计入", status: .done), under: deletedParent)
        // 有效子任务全部删除 → 接管解除，父任务视为叶子，按手动 halfDone 计 0.5
        let released = insert(TaskItem(name: "接管解除父", status: .halfDone), into: goal)
        insert(TaskItem(name: "删除子", status: .deleted), under: released)
        try context.save()

        let leafProgress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(leafProgress.totalItems, 1, "仅叶子模式：删除父子树排除，接管解除父计为叶子")
        XCTAssertEqual(leafProgress.completedWeight, 0.5, accuracy: 0.000001)

        goal.progressCountingMode = .allTasks
        let allProgress = ProgressEngine.goalProgress(of: goal)
        XCTAssertEqual(allProgress.totalItems, 1, "全部任务模式：删除父整棵子树同样排除")
        XCTAssertEqual(allProgress.completedWeight, 0.5, accuracy: 0.000001)
    }

    // MARK: - 子任务贡献

    /// childContribution：单项 → (状态权重, 1)；进度 → 有效 (current, total)；删除态返回 (0, 0)
    func testChildContribution() throws {
        let done = TaskItem(name: "完成", status: .done)
        let half = TaskItem(name: "半完成", status: .halfDone)
        let deleted = TaskItem(name: "删除", status: .deleted)
        let progressLeaf = TaskItem(name: "进度", type: .progress, totalAmount: 8, currentAmount: 4)
        for task in [done, half, deleted, progressLeaf] { context.insert(task) }
        try context.save()

        XCTAssertEqual(ProgressEngine.childContribution(of: done).current, 1)
        XCTAssertEqual(ProgressEngine.childContribution(of: done).total, 1)
        XCTAssertEqual(ProgressEngine.childContribution(of: half).current, 0.5)
        XCTAssertEqual(ProgressEngine.childContribution(of: half).total, 1)
        XCTAssertEqual(ProgressEngine.childContribution(of: deleted).current, 0, "删除态返回 0，由调用方跳过")
        XCTAssertEqual(ProgressEngine.childContribution(of: deleted).total, 0)
        XCTAssertEqual(ProgressEngine.childContribution(of: progressLeaf).current, 4)
        XCTAssertEqual(ProgressEngine.childContribution(of: progressLeaf).total, 8)
    }

    // MARK: - 继承链解析

    /// 继承链：颜色/图标/日期沿父链向上取最近已设置值，直到 Goal 层级；无归属回退黑色
    func testInheritanceChainResolution() throws {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = Date(timeIntervalSince1970: 2_000_000)
        let goal = Goal(name: "目标", colorHex: "#0000FF", iconSystemName: "star", startDate: start, endDate: end)
        context.insert(goal)

        // 一级设置红色，二三级不设置 → 直接 / 跨层继承
        let top = insert(TaskItem(name: "一级", colorHex: "#FF3B30"), into: goal)
        let mid = insert(TaskItem(name: "二级"), under: top)
        let leaf = insert(TaskItem(name: "三级"), under: mid)
        try context.save()

        XCTAssertEqual(ProgressEngine.effectiveColor(of: top), "#FF3B30")
        XCTAssertEqual(ProgressEngine.effectiveColor(of: mid), "#FF3B30", "直接继承父任务颜色")
        XCTAssertEqual(ProgressEngine.effectiveColor(of: leaf), "#FF3B30", "跨层继承")

        // 全链未设置 → 回退 Goal 层级
        let bare = insert(TaskItem(name: "无属性"), into: goal)
        XCTAssertEqual(ProgressEngine.effectiveColor(of: bare), "#0000FF", "回退目标颜色")
        XCTAssertEqual(ProgressEngine.effectiveIcon(of: bare), "star")
        XCTAssertEqual(ProgressEngine.effectiveStartDate(of: bare), start)
        XCTAssertEqual(ProgressEngine.effectiveEndDate(of: bare), end)

        // 深层未设置同样回退到 Goal；rootGoal 沿父链找到所属目标
        XCTAssertEqual(ProgressEngine.effectiveIcon(of: leaf), "star")
        XCTAssertEqual(ProgressEngine.effectiveStartDate(of: leaf), start)
        XCTAssertEqual(ProgressEngine.effectiveEndDate(of: leaf), end)
        XCTAssertTrue(ProgressEngine.rootGoal(of: leaf) === goal)

        // 无归属任务：rootGoal 为 nil，颜色回退黑色
        let detached = TaskItem(name: "游离")
        context.insert(detached)
        XCTAssertNil(ProgressEngine.rootGoal(of: detached))
        XCTAssertEqual(ProgressEngine.effectiveColor(of: detached), "#000000")
    }
}
