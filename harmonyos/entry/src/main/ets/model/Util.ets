import util from '@ohos.util';

/** 生成随机 UUID（HarmonyOS 原生 util） */
export function genId(): string {
  return util.generateRandomUUID(true);
}

/** 数值截断到 [lo, hi] */
export function clamp(value: number, lo: number, hi: number): number {
  return Math.min(Math.max(value, lo), hi);
}

/** 当前时间戳（毫秒） */
export function now(): number {
  return Date.now();
}

/**
 * 将 JS Date.getDay()（0=周日…6=周六）转换为本项目约定的星期编码
 * （1=周日…7=周六，与 spec 一致）。
 */
export function toWeekdayCode(jsDay: number): number {
  return jsDay + 1;
}