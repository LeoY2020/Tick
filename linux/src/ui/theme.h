#pragma once

#include <QColor>
#include <QPair>
#include <QString>
#include <QVector>

namespace tick {

// 预设色板（12 色，与 iOS 版对齐）
struct ColorInfo {
    QString name;
    QString hex;
};

const QVector<ColorInfo>& goalColorPalette();

/// 应用全局配色方案："system"（跟随系统）/ "light"（亮色）/ "dark"（暗色）
void applyAppPalette(const QString& scheme);

/// 解析 HEX 颜色："auto" 按深色/浅色适配（深色白 / 浅色黑）；
/// 支持 "#RRGGBB" / "RRGGBB" / 3 位缩写；无效返回黑色
QColor resolveColor(const QString& hex, bool dark);

} // namespace tick