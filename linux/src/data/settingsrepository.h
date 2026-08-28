#pragma once

#include <QSettings>
#include <QString>

#include "model/enums.h"

namespace tick {

// 设置存储：QSettings（主题、AI 模型、API Key、Base URL、模型名）
class SettingsRepository {
public:
    // 主题：system / light / dark
    QString colorScheme() const;
    void setColorScheme(const QString& scheme);

    // 语言："zh"（简体中文） / "en"（English）
    QString language() const;
    void setLanguage(const QString& lang);

    AIProvider aiProvider() const;
    void setAiProvider(AIProvider provider);

    QString apiKey() const;
    void setApiKey(const QString& key);

    QString baseUrl() const;
    void setBaseUrl(const QString& url);

    QString modelName() const;
    void setModelName(const QString& name);

private:
    QSettings settings() const;
};

} // namespace tick