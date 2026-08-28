#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <QVector>

#include <memory>
#include <vector>

#include "model/enums.h"

class QNetworkReply;

namespace tick {

// AI 配置（OpenAI 兼容接口）
struct AIConfig {
    AIProvider provider = AIProvider::DeepSeek;
    QString apiKey;
    QString baseUrl;
    QString modelName;
};

// 发送用对话消息
struct AIMessage {
    QString role;    // "user" / "assistant"
    QString content;
};

// AI 生成的任务树节点（宽容解析：缺字段不失败）
struct GeneratedTask {
    QString name;
    std::vector<std::shared_ptr<GeneratedTask>> children;

    static std::shared_ptr<GeneratedTask> fromJson(const QJsonValue& value);
    static void appendFromArray(const QJsonValue& value, std::vector<std::shared_ptr<GeneratedTask>>& out);
};

// 一次聊天回复的结构化结果：是否生成任务、生成的任务树、以及展示文字
struct ChatReplyParse {
    bool shouldGenerateTask = false;
    std::vector<std::shared_ptr<GeneratedTask>> tasks;
    QString message;
};

// AI 服务：QNetworkAccessManager 实现，非流式 OpenAI 兼容 /chat/completions
class AIService : public QObject {
    Q_OBJECT
public:
    explicit AIService(QObject* parent = nullptr);
    ~AIService() override;

    // 从设置读取并解析为 AIConfig（空 Base URL / 模型名回退到供应商预设）
    static AIConfig configFromSettings();

    // 聊天系统提示词（要求输出 JSON envelope，且严禁生成空泛任务）
    static QString chatSystemPrompt();

    // 解析模型返回内容的 JSON envelope：
    // {"generate":true,"tasks":[{"name":"","children":[]}],"message":""}
    // 失败或非 generate 时，把原文当普通文字展示（宽容回退）
    static ChatReplyParse parseChatReply(const QString& raw);

    bool busy() const;

    void send(const AIConfig& config, const QString& systemPrompt,
              const QVector<AIMessage>& history);

signals:
    void finished(const QString& content);
    void failed(const QString& error);

private slots:
    void onReplyFinished();

private:
    QString endpointUrl(const QString& baseUrl) const;

    QNetworkAccessManager manager_;
    QNetworkReply* reply_ = nullptr;
};

} // namespace tick