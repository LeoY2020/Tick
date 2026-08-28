#include "ui/theme.h"

#include <QApplication>
#include <QPalette>
#include <QStyle>

namespace tick {

const QVector<ColorInfo>& goalColorPalette() {
    static const QVector<ColorInfo> s_palette = {
        { QStringLiteral("黑色"), QStringLiteral("#000000") },
        { QStringLiteral("红色"), QStringLiteral("#FF3B30") },
        { QStringLiteral("橙色"), QStringLiteral("#FF9500") },
        { QStringLiteral("黄色"), QStringLiteral("#FFCC00") },
        { QStringLiteral("绿色"), QStringLiteral("#34C759") },
        { QStringLiteral("薄荷绿"), QStringLiteral("#00C7BE") },
        { QStringLiteral("青色"), QStringLiteral("#30B0C7") },
        { QStringLiteral("蓝色"), QStringLiteral("#007AFF") },
        { QStringLiteral("靛蓝"), QStringLiteral("#5856D6") },
        { QStringLiteral("紫色"), QStringLiteral("#AF52DE") },
        { QStringLiteral("粉色"), QStringLiteral("#FF2D55") },
        { QStringLiteral("棕色"), QStringLiteral("#A2845E") },
    };
    return s_palette;
}

QColor resolveColor(const QString& hexIn, bool dark) {
    if (hexIn.compare(QStringLiteral("auto"), Qt::CaseInsensitive) == 0) {
        return dark ? QColor(Qt::white) : QColor(Qt::black);
    }
    QString value = hexIn.trimmed();
    if (value.startsWith(QLatin1Char('#'))) value.remove(0, 1);
    // 3 位缩写扩展为 6 位
    if (value.size() == 3) {
        QString expanded;
        for (const QChar c : value) {
            expanded += c;
            expanded += c;
        }
        value = expanded;
    }
    if (value.size() != 6) return QColor(Qt::black);
    bool ok = false;
    const uint rgb = value.toUInt(&ok, 16);
    if (!ok) return QColor(Qt::black);
    return QColor(static_cast<int>((rgb >> 16) & 0xFF),
                  static_cast<int>((rgb >> 8) & 0xFF),
                  static_cast<int>(rgb & 0xFF));
}

void applyAppPalette(const QString& scheme) {
    if (scheme == QLatin1String("system")) {
        QApplication::setPalette(QApplication::style()->standardPalette());
        return;
    }
    const bool dark = (scheme == QLatin1String("dark"));
    QPalette p;
    if (dark) {
        p.setColor(QPalette::Window, QColor(0x2b, 0x2b, 0x2b));
        p.setColor(QPalette::WindowText, QColor(0xec, 0xec, 0xec));
        p.setColor(QPalette::Base, QColor(0x23, 0x23, 0x23));
        p.setColor(QPalette::AlternateBase, QColor(0x2f, 0x2f, 0x2f));
        p.setColor(QPalette::ToolTipBase, QColor(0x1c, 0x1c, 0x1c));
        p.setColor(QPalette::ToolTipText, QColor(0xec, 0xec, 0xec));
        p.setColor(QPalette::Text, QColor(0xec, 0xec, 0xec));
        p.setColor(QPalette::Button, QColor(0x3c, 0x3c, 0x3c));
        p.setColor(QPalette::ButtonText, QColor(0xec, 0xec, 0xec));
        p.setColor(QPalette::BrightText, Qt::red);
        p.setColor(QPalette::Link, QColor(0x5a, 0xa0, 0xff));
        p.setColor(QPalette::Highlight, QColor(0x2a, 0x82, 0xff));
        p.setColor(QPalette::HighlightedText, Qt::black);
        p.setColor(QPalette::PlaceholderText, QColor(0x90, 0x90, 0x90));
    } else {
        p.setColor(QPalette::Window, QColor(0xF6, 0xF6, 0xF6));
        p.setColor(QPalette::WindowText, QColor(0x1c, 0x1c, 0x1c));
        p.setColor(QPalette::Base, Qt::white);
        p.setColor(QPalette::AlternateBase, QColor(0xf2, 0xf2, 0xf2));
        p.setColor(QPalette::ToolTipBase, QColor(0xff, 0xff, 0xdc));
        p.setColor(QPalette::ToolTipText, QColor(0x1c, 0x1c, 0x1c));
        p.setColor(QPalette::Text, QColor(0x1c, 0x1c, 0x1c));
        p.setColor(QPalette::Button, QColor(0xef, 0xef, 0xef));
        p.setColor(QPalette::ButtonText, QColor(0x1c, 0x1c, 0x1c));
        p.setColor(QPalette::BrightText, Qt::red);
        p.setColor(QPalette::Link, QColor(0x007AFF));
        p.setColor(QPalette::Highlight, QColor(0x007AFF));
        p.setColor(QPalette::HighlightedText, Qt::white);
        p.setColor(QPalette::PlaceholderText, QColor(0x99, 0x99, 0x99));
    }
    p.setColor(QPalette::Disabled, QPalette::Text, QColor(0xaa, 0xaa, 0xaa));
    p.setColor(QPalette::Disabled, QPalette::ButtonText, QColor(0xaa, 0xaa, 0xaa));
    p.setColor(QPalette::Disabled, QPalette::WindowText, QColor(0xaa, 0xaa, 0xaa));
    p.setColor(QPalette::Disabled, QPalette::Highlight, QColor(0x55, 0x88, 0xbb));
    p.setColor(QPalette::Disabled, QPalette::HighlightedText, QColor(0xdd, 0xdd, 0xdd));
    QApplication::setPalette(p);
}

} // namespace tick