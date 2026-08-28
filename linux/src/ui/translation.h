#pragma once

#include <QString>

namespace tick {

// 轻量多语言：简体中文 / English。
// - lang() 读取当前语言（"zh" / "en"），由 SettingsRepository 决定。
// - t(zh, en) 根据当前语言返回对应字符串。
// 不做完整 .ts 国际化，以满足"简单实现"要求，切换后新建的界面立即生效。
class Tr {
public:
    static QString lang();
    static void setLang(const QString& lang);
    static void loadFromSettings();
    static QString t(const QString& zh, const QString& en);

private:
    inline static QString s_lang = QStringLiteral("zh");
};

// 便捷宏：按当前语言返回其中文或英文字符串
#define TR(zh, en) (::tick::Tr::t(QStringLiteral(zh), QStringLiteral(en)))

} // namespace tick