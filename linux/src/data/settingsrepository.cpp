#include "data/settingsrepository.h"

namespace tick {

QSettings SettingsRepository::settings() const {
    return QSettings();
}

QString SettingsRepository::colorScheme() const {
    return settings().value(QStringLiteral("theme/colorScheme"), QStringLiteral("system")).toString();
}

void SettingsRepository::setColorScheme(const QString& scheme) {
    settings().setValue(QStringLiteral("theme/colorScheme"), scheme);
}

QString SettingsRepository::language() const {
    return settings().value(QStringLiteral("app/language"), QStringLiteral("zh")).toString();
}

void SettingsRepository::setLanguage(const QString& lang) {
    settings().setValue(QStringLiteral("app/language"), lang);
}

AIProvider SettingsRepository::aiProvider() const {
    const QString raw = settings().value(QStringLiteral("ai/provider"),
                                         aiProviderToString(AIProvider::DeepSeek)).toString();
    return aiProviderFromString(raw, AIProvider::DeepSeek);
}

void SettingsRepository::setAiProvider(AIProvider provider) {
    settings().setValue(QStringLiteral("ai/provider"), aiProviderToString(provider));
}

QString SettingsRepository::apiKey() const {
    return settings().value(QStringLiteral("ai/apiKey")).toString();
}

void SettingsRepository::setApiKey(const QString& key) {
    settings().setValue(QStringLiteral("ai/apiKey"), key);
}

QString SettingsRepository::baseUrl() const {
    return settings().value(QStringLiteral("ai/baseUrl")).toString();
}

void SettingsRepository::setBaseUrl(const QString& url) {
    settings().setValue(QStringLiteral("ai/baseUrl"), url);
}

QString SettingsRepository::modelName() const {
    return settings().value(QStringLiteral("ai/modelName")).toString();
}

void SettingsRepository::setModelName(const QString& name) {
    settings().setValue(QStringLiteral("ai/modelName"), name);
}

} // namespace tick