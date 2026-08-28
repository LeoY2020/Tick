import { I18n } from '../model/I18n';

/**
 * 截止日期倒计时格式化工具（纯计算）。
 * 规则（同 iOS 版，取最大有效单位层级）：
 * - 剩余 ≥ 1 年：`X年Y月`（月为 0 时省略月）
 * - 剩余 ≥ 1 月：`X月Y日`（日为 0 时省略日）
 * - 剩余 ≥ 1 日：`X日Y时`（未精确到小时，或剩余时为 0，省略时）
 * - 剩余 < 1 日且精确到小时且时 > 0：`X时`
 * 剩余不足以显示或已过期时返回 undefined。
 */
export class CountdownFormatter {
  static countdown(endMs: number, preciseToHour: boolean, nowMs: number = Date.now()): string | undefined {
    if (endMs <= nowMs) {
      return undefined;
    }

    const start = new Date(nowMs);
    let year = new Date(endMs).getFullYear() - start.getFullYear();
    let month = new Date(endMs).getMonth() - start.getMonth();
    let day = new Date(endMs).getDate() - start.getDate();
    let hour = new Date(endMs).getHours() - start.getHours();

    // 借位统一为自然单位
    if (hour < 0) {
      hour += 24;
      day -= 1;
    }
    if (day < 0) {
      // 向上一个月借天数（取后一个月月初换算）
      const prev = new Date(endMs);
      const daysInPrevMonth = new Date(prev.getFullYear(), prev.getMonth(), 0).getDate();
      day += daysInPrevMonth;
      month -= 1;
    }
    if (month < 0) {
      month += 12;
      year -= 1;
    }

    const zhL = (s: string): string => I18n.L(s, s === '年' ? 'yr ' : s === '月' ? 'mo ' : s === '日' ? 'd ' : s === '时' ? 'h' : s);

    if (year >= 1) {
      return month > 0 ? `${year}${zhL('年')}${month}${zhL('月')}` : `${year}${zhL('年')}`;
    }
    if (month >= 1) {
      return day > 0 ? `${month}${zhL('月')}${day}${zhL('日')}` : `${month}${zhL('月')}`;
    }
    if (day >= 1) {
      return (preciseToHour && hour > 0) ? `${day}${zhL('日')}${hour}${zhL('时')}` : `${day}${zhL('日')}`;
    }
    if (hour > 0) {
      return preciseToHour ? `${hour}${zhL('时')}` : undefined;
    }
    return undefined;
  }

  /** 结束时间展示文本（含分秒视是否精确到小时） */
  static endDateLabel(endMs: number, preciseToHour: boolean): string {
    const d = new Date(endMs);
    const pad = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString());
    if (preciseToHour) {
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
    }
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  }

  /** 时间戳 → 日期时间文本（用于编辑弹窗展示与提醒） */
  static dateTimeLabel(ms: number): string {
    const d = new Date(ms);
    const pad = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString());
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }
}