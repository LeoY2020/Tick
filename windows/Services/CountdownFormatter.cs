namespace Tick.Services;

/// <summary>
/// 截止日期倒计时格式化工具（纯计算，供目标主界面标题右侧展示）。
/// 忠实移植 iOS 版 CountdownFormatter 的层级规则。
/// </summary>
public static class CountdownFormatter
{
    /// <summary>
    /// 计算从 now 到 endDate 的剩余时间，并按规则生成倒计时文本。
    /// 规则（取最大有效单位层级）：
    /// - 剩余 ≥ 1 年：X年Y月（月为 0 省略月）
    /// - 剩余 ≥ 1 月：X月Y日（日为 0 省略日）
    /// - 剩余 ≥ 1 日：X日Y时（未开启精确到小时，或剩余时为 0，省略时）
    /// - 剩余 &lt; 1 日且精确到小时且时 &gt; 0：X时
    /// </summary>
    public static string? Countdown(DateTime endDate, bool preciseToHour, DateTime? now = null)
    {
        DateTime nowv = now ?? DateTime.Now;
        if (endDate <= nowv)
            return null;

        int year = endDate.Year - nowv.Year;
        int month = endDate.Month - nowv.Month;
        int day = endDate.Day - nowv.Day;
        int hour = endDate.Hour - nowv.Hour;
        if (hour < 0)
        {
            hour += 24;
            day--;
        }
        if (day < 0)
        {
            month--;
            var prev = endDate.AddMonths(-1);
            day += DateTime.DaysInMonth(prev.Year, prev.Month);
        }
        if (month < 0)
        {
            month += 12;
            year--;
        }

        if (year >= 1)
            return month > 0
                ? string.Format(Localization.Tr("countdown.yearMonth"), year, month)
                : string.Format(Localization.Tr("countdown.year"), year);
        if (month >= 1)
            return day > 0
                ? string.Format(Localization.Tr("countdown.monthDay"), month, day)
                : string.Format(Localization.Tr("countdown.month"), month);
        if (day >= 1)
            return preciseToHour && hour > 0
                ? string.Format(Localization.Tr("countdown.dayHour"), day, hour)
                : string.Format(Localization.Tr("countdown.day"), day);
        if (hour > 0)
            return preciseToHour ? string.Format(Localization.Tr("countdown.hour"), hour) : null;
        return null;
    }
}