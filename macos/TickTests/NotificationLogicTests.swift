import XCTest
@testable import Tick

/// 通知触发器纯逻辑测试（不请求真实通知权限）
final class NotificationLogicTests: XCTestCase {
    /// 固定已知日期：2026-08-24 09:30（周一，weekday=2）
    /// 用当前日历构造，避免时区/夏令时偶发
    private static let fixedDate: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 24
        comps.hour = 9
        comps.minute = 30
        return Calendar.current.date(from: comps)!
    }()

    // MARK: - identifiers

    /// 全部标识符：基础 id + "-w1"…"-w7" 共 8 个
    func testIdentifiersContainAllVariants() {
        let id = UUID()
        let ids = NotificationService.identifiers(for: id)

        XCTAssertEqual(ids.count, 8)
        XCTAssertEqual(ids.first, id.uuidString, "应包含基础 id")
        for weekday in 1...7 {
            XCTAssertTrue(ids.contains("\(id.uuidString)-w\(weekday)"), "缺少 -w\(weekday) 变体")
        }
    }

    // MARK: - triggerPlacements

    /// 不重复：一条，精确到年月日时分
    func testNeverPlacement() {
        let id = UUID()
        let placements = NotificationService.triggerPlacements(rule: .never,
                                                               date: Self.fixedDate,
                                                               weekdays: [],
                                                               taskID: id)

        XCTAssertEqual(placements.count, 1)
        XCTAssertEqual(placements[0].identifier, id.uuidString)
        let comps = placements[0].components
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 8)
        XCTAssertEqual(comps.day, 24)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 30)
    }

    /// 每天：一条，仅时分
    func testDailyPlacement() {
        let id = UUID()
        let placements = NotificationService.triggerPlacements(rule: .daily,
                                                               date: Self.fixedDate,
                                                               weekdays: [],
                                                               taskID: id)

        XCTAssertEqual(placements.count, 1)
        XCTAssertEqual(placements[0].identifier, id.uuidString)
        let comps = placements[0].components
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 30)
        XCTAssertNil(comps.year)
        XCTAssertNil(comps.month)
        XCTAssertNil(comps.day)
        XCTAssertNil(comps.weekday)
    }

    /// 每周：一条，含星期几 + 时分
    func testWeeklyPlacement() {
        let id = UUID()
        let placements = NotificationService.triggerPlacements(rule: .weekly,
                                                               date: Self.fixedDate,
                                                               weekdays: [],
                                                               taskID: id)

        XCTAssertEqual(placements.count, 1)
        XCTAssertEqual(placements[0].identifier, id.uuidString)
        let comps = placements[0].components
        // 期望值取自同一日期（2026-08-24 为周一，weekday=2）
        XCTAssertEqual(comps.weekday, Calendar.current.component(.weekday, from: Self.fixedDate))
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 30)
        XCTAssertNil(comps.day)
        XCTAssertNil(comps.month)
    }

    /// 每月：一条，含几号 + 时分，不含 month（跨月重复）
    func testMonthlyPlacement() {
        let id = UUID()
        let placements = NotificationService.triggerPlacements(rule: .monthly,
                                                               date: Self.fixedDate,
                                                               weekdays: [],
                                                               taskID: id)

        XCTAssertEqual(placements.count, 1)
        XCTAssertEqual(placements[0].identifier, id.uuidString)
        let comps = placements[0].components
        XCTAssertEqual(comps.day, 24)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 30)
        XCTAssertNil(comps.month, "不应包含 month，否则无法跨月重复")
        XCTAssertNil(comps.year)
        XCTAssertNil(comps.weekday)
    }

    /// 自定义：weekdays [1,3,5] → 3 条，标识符含 -w1/-w3/-w5，各含对应 weekday
    func testCustomPlacements() {
        let id = UUID()
        let placements = NotificationService.triggerPlacements(rule: .custom,
                                                               date: Self.fixedDate,
                                                               weekdays: [1, 3, 5],
                                                               taskID: id)

        XCTAssertEqual(placements.count, 3)

        let byIdentifier = Dictionary(uniqueKeysWithValues: placements.map { ($0.identifier, $0.components) })
        for weekday in [1, 3, 5] {
            let key = "\(id.uuidString)-w\(weekday)"
            let comps = byIdentifier[key]
            XCTAssertNotNil(comps, "缺少标识符 \(key)")
            XCTAssertEqual(comps?.weekday, weekday, "\(key) 的 weekday 应为 \(weekday)")
            XCTAssertEqual(comps?.hour, 9)
            XCTAssertEqual(comps?.minute, 30)
            XCTAssertNil(comps?.day)
        }
    }

    /// 自定义空周几：回退为每天行为（1 条，仅时分）
    func testCustomEmptyWeekdaysFallback() {
        let id = UUID()
        let placements = NotificationService.triggerPlacements(rule: .custom,
                                                               date: Self.fixedDate,
                                                               weekdays: [],
                                                               taskID: id)

        XCTAssertEqual(placements.count, 1)
        XCTAssertEqual(placements[0].identifier, id.uuidString)
        let comps = placements[0].components
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 30)
        XCTAssertNil(comps.weekday)
        XCTAssertNil(comps.day)
    }
}
