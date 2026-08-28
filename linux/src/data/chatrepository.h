#pragma once

#include <QDateTime>
#include <QString>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "model/enums.h"

namespace tick {

// 一条对话消息（AI 聊天 / 生成任务共用）
struct ChatMessage {
    QString role;   // "user" / "assistant"
    QString text;
    QDateTime createdAt = QDateTime::currentDateTime();
};

// 一次 AI 会话（持久化到 AIChatSession 表，消息以 JSON 编码）
struct ChatSession {
    std::string id = makeId();
    std::optional<std::string> goalId;
    QString title;
    QDateTime createdAt = QDateTime::currentDateTime();
    QDateTime updatedAt = QDateTime::currentDateTime();
    std::vector<ChatMessage> messages;
    std::optional<QString> attachmentName;
    std::optional<QString> attachmentText;
};

// AI 会话仓储
class ChatRepository {
public:
    std::vector<std::shared_ptr<ChatSession>> sessionsForGoal(const std::string& goalId);
    std::shared_ptr<ChatSession> findById(const std::string& id);
    void save(const ChatSession& session);
    void remove(const std::string& id);

private:
    static QString encodeMessages(const std::vector<ChatMessage>& messages);
    static std::vector<ChatMessage> decodeMessages(const QString& json);
};

} // namespace tick