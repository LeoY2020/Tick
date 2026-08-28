import XCTest
@testable import Tick

/// 截止日期倒计时格式化测试（注入固定 now，避免时间漂移）
final class CountdownFormatterTests: XCTestCase {

    private var calendar: Calendar!
    private var now: Date!

    override func setUpWithError() throws {
        calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 15
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        now = calendar.date(from: comps)!
    }

    /// 已过 / 等于当前时刻 → nil
    func testPastOrNowReturnsNil() {
        let past = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertNil(CountdownFormatter.countdown(to: past, preciseToHour: true, now: now))
        XCTAssertNil(CountdownFormatter.countdown(to: now, preciseToHour: true, now: now))
    }

    /// ≥1 年：年月（月为 0 省略月）
    func testYearMonthFormatting() {
        let oneYear = calendar.date(byAdding: .year, value: 1, to: now)!
        XCTAssertEqual(CountdownFormatter.countdown(to: oneYear, preciseToHour: true, now: now), "1年", "整年省略月")

        let oneYearTwoMonth = calendar.date(byAdding: DateComponents(year: 1, month: 2), to: now)!
        XCTAssertEqual(CountdownFormatter.countdown(to: oneYearTwoMonth, preciseToHour: true, now: now), "1年2月")
    }

    /// ≥1 月：月日（日为 0 省略日）
    func testMonthDayFormatting() {
        let oneMonth = calendar.date(byAdding: .month, value: 1, to: now)!
        XCTAssertEqual(CountdownFormatter.countdown(to: oneMonth, preciseToHour: true, now: now), "1月", "整月省略日")

        let oneMonthTenDay = calendar.date(byAdding: DateComponents(month: 1, day: 10), to: now)!
        XCTAssertEqual(CountdownFormatter.countdown(to: oneMonthTenDay, preciseToHour: true, now: now), "1月10日")
    }

    /// ≥1 日：日时（未开精确到小时，或剩余时为 0，都省略时）
    func testDayHourFormatting() {
        let fiveDay = calendar.date(byAdding: .day, value: 5, to: now)!
        XCTAssertEqual(CountdownFormatter.countdown(to: fiveDay, preciseToHour: true, now: now), "5日", "剩余时为 0 省略时")
        XCTAssertEqual(CountdownFormatter.countdown(to: fiveDay, preciseToHour: false, now: now), "5日")

        let fiveDayThreeHour = calendar.date(byAdding: DateComponents(day: 5, hour: 3), to: now)!
        XCTAssertEqual(CountdownFormatter.countdown(to: fiveDayThreeHour, preciseToHour: true, now: now), "5日3时")
        XCTAssertEqual(CountdownFormatter.countdown(to: fiveDayThreeHour, preciseToHour: false, now: now), "5日", "未开精确到小时省略时")
    }

    /// <1 日：仅显示时（未开精确到小时则不显示）
    func testHourOnlyFormatting() {
        let threeHour = calendar.date(byAdding: .hour, value: 3, to: now)!
        XCTAssertEqual(CountdownFormatter.countdown(to: threeHour, preciseToHour: true, now: now), "3时")
        XCTAssertNil(CountdownFormatter.countdown(to: threeHour, preciseToHour: false, now: now), "未开精确到小时且不足 1 日 → 不显示")
    }

    /// 不足 1 小时 → nil
    func testSubOneHourReturnsNil() {
        let thirtyMinutes = calendar.date(byAdding: .minute, value: 30, to: now)!
        XCTAssertNil(CountdownFormatter.countdown(to: thirtyMinutes, preciseToHour: true, now: now))
    }
}