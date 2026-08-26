import XCTest
import SwiftData
@testable import Tick

/// SwiftData 数据模型层测试（内存容器）
final class ModelTests: XCTestCase {
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

    /// 构建 目标 → 任务A → 子任务B → 孙任务C 三层结构并保存
    @discardableResult
    private func makeTaskTree(goalName: String = "目标") throws -> (Goal, TaskItem, TaskItem, TaskItem) {
        let goal = Goal(name: goalName)
        let taskA = TaskItem(name: "A")
        let taskB = TaskItem(name: "B")
        let taskC = TaskItem(name: "C")
        context.insert(goal)
        context.insert(taskA)
        context.insert(taskB)
        context.insert(taskC)
        taskA.attach(to: goal)
        taskB.attach(to: taskA)
        taskC.attach(to: taskB)
        try context.save()
        return (goal, taskA, taskB, taskC)
    }

    // MARK: - 用例

    /// 创建目标与一级任务并 fetch 验证持久化
    func testCreateGoalAndTopLevelTask() throws {
        let goal = Goal(name: "健身", colorHex: "#FF3B30", iconSystemName: "figure.run")
        let task = TaskItem(name: "跑步")
        context.insert(goal)
        context.insert(task)
        task.attach(to: goal)
        try context.save()

        let goals = try context.fetch(FetchDescriptor<Goal>())
        XCTAssertEqual(goals.count, 1)
        let savedGoal = try XCTUnwrap(goals.first)
        XCTAssertEqual(savedGoal.name, "健身")
        XCTAssertEqual(savedGoal.colorHex, "#FF3B30")
        XCTAssertEqual(savedGoal.iconSystemName, "figure.run")
        XCTAssertEqual(savedGoal.tasks.count, 1)

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.count, 1)
        let savedTask = try XCTUnwrap(tasks.first)
        XCTAssertEqual(savedTask.name, "跑步")
        XCTAssertEqual(savedTask.goal?.name, "健身")
        XCTAssertNil(savedTask.parentTask)
        XCTAssertFalse(savedTask.hasSubtasks)
    }

    /// 自引用关系：三层结构 fetch 后验证 parentTask/subtasks 双向正确
    func testSelfReferencingRelationship() throws {
        try makeTaskTree(goalName: "项目")

        // 用全新 context 从存储重新读取，验证自引用序列化/反序列化
        let freshContext = ModelContext(container)
        let tasks = try freshContext.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.count, 3)

        let taskA = try XCTUnwrap(tasks.first { $0.name == "A" })
        let taskB = try XCTUnwrap(tasks.first { $0.name == "B" })
        let taskC = try XCTUnwrap(tasks.first { $0.name == "C" })

        // A：一级任务，挂 goal，子任务为 B
        XCTAssertEqual(taskA.goal?.name, "项目")
        XCTAssertNil(taskA.parentTask)
        XCTAssertTrue(taskA.hasSubtasks)
        XCTAssertEqual(taskA.subtasks.count, 1)
        XCTAssertEqual(taskA.subtasks.first?.name, "B")

        // B：父为 A，子为 C，不直接挂 goal（通过父链继承）
        XCTAssertEqual(taskB.parentTask?.name, "A")
        XCTAssertNil(taskB.goal)
        XCTAssertEqual(taskB.subtasks.count, 1)
        XCTAssertEqual(taskB.subtasks.first?.name, "C")

        // C：叶子任务，父为 B
        XCTAssertEqual(taskC.parentTask?.name, "B")
        XCTAssertFalse(taskC.hasSubtasks)
        XCTAssertEqual(taskC.subtasks.count, 0)
    }

    /// 删除任务A后其所有后代（B、C）被级联删除
    func testCascadeDelete() throws {
        let (_, taskA, _, _) = try makeTaskTree()

        context.delete(taskA)
        try context.save()

        // B、C 随 A 级联删除
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertTrue(tasks.isEmpty)

        // 目标不受影响
        let goals = try context.fetch(FetchDescriptor<Goal>())
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.tasks.count, 0)
    }

    /// setProgress 超过总量与负值时被 clamp
    func testProgressClamp() throws {
        let task = TaskItem(name: "跑步", type: .progress, totalAmount: 10)
        context.insert(task)

        task.setProgress(15)
        XCTAssertEqual(task.currentAmount, 10, "超过总量应 clamp 到总量")

        task.setProgress(-3)
        XCTAssertEqual(task.currentAmount, 0, "负值应 clamp 到 0")

        task.setProgress(7)
        XCTAssertEqual(task.currentAmount, 7, "合法值保持不变")

        // init 中同样 clamp
        let over = TaskItem(name: "阅读", type: .progress, totalAmount: 5, currentAmount: 8)
        XCTAssertEqual(over.currentAmount, 5, "init 时超过总量应 clamp")
        let under = TaskItem(name: "写作", type: .progress, totalAmount: 5, currentAmount: -2)
        XCTAssertEqual(under.currentAmount, 0, "init 时负值应 clamp")
    }

    /// 删除 Goal 后其任务树全部删除
    func testDeleteCascadeFromGoal() throws {
        let (goal, _, _, _) = try makeTaskTree(goalName: "学习")

        context.delete(goal)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Goal>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TaskItem>()).isEmpty, "目标删除后整棵任务树应被级联删除")
    }
}
