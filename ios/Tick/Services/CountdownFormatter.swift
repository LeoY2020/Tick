import Foundation

/// 截止日期倒计时格式化工具（纯计算，供目标主界面标题右侧展示）
enum CountdownFormatter {

    /// 计算从 now 到 endDate 的剩余时间，并按规则生成倒计时文本。
    ///
    /// 规则（取最大有效单位层级）：
    /// - 剩余 ≥ 1 年：`X年Y月`（月为 0 省略月）
    /// - 剩余 ≥ 1 月：`X月Y日`（日为 0 省略日）
    /// - 剩余 ≥ 1 日：`X日Y时`（未开启精确到小时，或剩余时为 0，省略时）
    /// - 剩余 < 1 日且精确到小时且时 > 0：`X时`
    ///
    /// - Parameters:
    ///   - endDate: 截止日期
    ///   - preciseToHour: 截止时间是否精确到小时（开启才显示"时"）
    ///   - now: 参照时刻（默认当前时间，便于测试注入）
    /// - Returns: 倒计时文本；`endDate ≤ now` 或剩余不足 1 小时（且非"日"层级）时返回 nil
    static func countdown(to endDate: Date, preciseToHour: Bool, now: Date = Date()) -> String? {
        guard endDate > now else { return nil }

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: now, to: endDate)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        let hour = comps.hour ?? 0

        if year >= 1 {
            return month > 0 ? "\(year)年\(month)月" : "\(year)年"
        } else if month >= 1 {
            return day > 0 ? "\(month)月\(day)日" : "\(month)月"
        } else if day >= 1 {
            return (preciseToHour && hour > 0) ? "\(day)日\(hour)时" : "\(day)日"
        } else if hour > 0 {
            return preciseToHour ? "\(hour)时" : nil
        } else {
            // 剩余不足 1 小时
            return nil
        }
    }
}