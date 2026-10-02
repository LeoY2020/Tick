#pragma once

#include <QString>

namespace tick {

// 轻量多语言（8 种：简体中文 / 繁體中文 / 日本語 / 한국어 / English / Français / Deutsch / Español）。
// - lang() 读取当前语言，由 SettingsRepository 决定。
// - setLang() 设置当前语言（语言代码：zh / zh-Hant / ja / ko / en / fr / de / es）。
// - t(zh, en)：优先按"简体中文 key→8 语言译文"查找表返回当前语言译文；
//   若 key 不在表中，回退旧逻辑（en 返回英译，其余语言返回中文）。
// 不做完整 .ts 国际化，以满足"简单实现"要求，切换后新建的界面立即生效。
class Tr {
public:
    // 返回 8 种受支持语言的代码列表（与查找表索引顺序一致）。
    static const QStringList& supportedLangs();

    static QString lang();
    static void setLang(const QString& lang);
    static void loadFromSettings();
    static QString t(const QString& zh, const QString& en);

private:
    inline static QString s_lang = QStringLiteral("zh");
};

// 便捷宏：按当前语言返回对应字符串（zh 为简体中文原文，en 为英文回退）
#define TR(zh, en) (::tick::Tr::t(QStringLiteral(zh), QStringLiteral(en)))

} // namespace tick