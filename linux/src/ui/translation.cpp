#include "ui/translation.h"

#include "data/settingsrepository.h"

namespace tick {

QString Tr::lang() {
    return s_lang;
}

void Tr::setLang(const QString& lang) {
    s_lang = lang;
}

void Tr::loadFromSettings() {
    SettingsRepository repo;
    s_lang = repo.language();
    if (s_lang.isEmpty()) s_lang = QStringLiteral("zh");
}

QString Tr::t(const QString& zh, const QString& en) {
    return s_lang == QLatin1String("en") ? en : zh;
}

} // namespace tick