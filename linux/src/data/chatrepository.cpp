#include "data/chatrepository.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QSqlQuery>
#include <QVariant>

#include "data/database.h"

namespace tick {

namespace {

inline QString q(const std::string& s) {
    return QString::fromStdString(s);
}

inline std::optional<std::string> optId(const QString& s) {
    if (s.isEmpty()) return std::nullopt;
    return std::optional<std::string>(s.toStdString());
}

} // namespace

QString ChatRepository::encodeMessages(const std::vector<ChatMessage>& messages) {
    QJsonArray arr;
    for (const auto& m : messages) {
        QJsonObject o;
        o.insert(QStringLiteral("role"), m.role);
        o.insert(QStringLiteral("text"), m.text);
        o.insert(QStringLiteral("createdAt"), m.createdAt.toString(Qt::ISODateWithMs));
        arr.append(o);
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

std::vector<ChatMessage> ChatRepository::decodeMessages(const QString& json) {
    std::vector<ChatMessage> out;
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isArray()) return out;
    const QJsonArray arr = doc.array();
    for (const auto& v : arr) {
        if (!v.isObject()) continue;
        const QJsonObject o = v.toObject();
        ChatMessage m;
        m.role = o.value(QStringLiteral("role")).toString();
        m.text = o.value(QStringLiteral("text")).toString();
        const QDateTime t = QDateTime::fromString(
            o.value(QStringLiteral("createdAt")).toString(), Qt::ISODateWithMs);
        m.createdAt = t.isValid() ? t : QDateTime::currentDateTime();
        out.push_back(m);
    }
    return out;
}

std::vector<std::shared_ptr<ChatSession>> ChatRepository::sessionsForGoal(const std::string& goalId) {
    std::vector<std::shared_ptr<ChatSession>> out;
    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral(
        "SELECT id, goal_id, title, created_at, updated_at, messages_json, message_count, "
        "attachment_name, attachment_text FROM AIChatSession WHERE goal_id = ? ORDER BY updated_at DESC"));
    query.addBindValue(q(goalId));
    if (!query.exec()) return out;
    while (query.next()) {
        auto s = std::make_shared<ChatSession>();
        s->id = query.value(0).toString().toStdString();
        s->goalId = optId(query.value(1).toString());
        s->title = query.value(2).toString();
        s->createdAt = dateTimeFromString(query.value(3).toString()).value_or(QDateTime::currentDateTime());
        s->updatedAt = dateTimeFromString(query.value(4).toString()).value_or(QDateTime::currentDateTime());
        s->messages = decodeMessages(query.value(5).toString());
        const QString an = query.value(7).toString();
        s->attachmentName = an.isEmpty() ? std::nullopt : std::optional<QString>(an);
        const QString at = query.value(8).toString();
        s->attachmentText = at.isEmpty() ? std::nullopt : std::optional<QString>(at);
        out.push_back(s);
    }
    return out;
}

std::shared_ptr<ChatSession> ChatRepository::findById(const std::string& id) {
    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral(
        "SELECT id, goal_id, title, created_at, updated_at, messages_json, message_count, "
        "attachment_name, attachment_text FROM AIChatSession WHERE id = ?"));
    query.addBindValue(q(id));
    if (!query.exec() || !query.next()) return nullptr;
    auto s = std::make_shared<ChatSession>();
    s->id = query.value(0).toString().toStdString();
    s->goalId = optId(query.value(1).toString());
    s->title = query.value(2).toString();
    s->createdAt = dateTimeFromString(query.value(3).toString()).value_or(QDateTime::currentDateTime());
    s->updatedAt = dateTimeFromString(query.value(4).toString()).value_or(QDateTime::currentDateTime());
    s->messages = decodeMessages(query.value(5).toString());
    const QString an = query.value(7).toString();
    s->attachmentName = an.isEmpty() ? std::nullopt : std::optional<QString>(an);
    const QString at = query.value(8).toString();
    s->attachmentText = at.isEmpty() ? std::nullopt : std::optional<QString>(at);
    return s;
}

void ChatRepository::save(const ChatSession& session) {
    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral(
        "INSERT INTO AIChatSession (id, goal_id, title, created_at, updated_at, messages_json, message_count, "
        "attachment_name, attachment_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(id) DO UPDATE SET "
        "goal_id = excluded.goal_id, title = excluded.title, updated_at = excluded.updated_at, "
        "messages_json = excluded.messages_json, message_count = excluded.message_count, "
        "attachment_name = excluded.attachment_name, attachment_text = excluded.attachment_text"));
    query.addBindValue(q(session.id));
    query.addBindValue(session.goalId.has_value() ? q(*session.goalId) : QVariant());
    query.addBindValue(session.title);
    query.addBindValue(session.createdAt.toString(Qt::ISODateWithMs));
    query.addBindValue(session.updatedAt.toString(Qt::ISODateWithMs));
    query.addBindValue(encodeMessages(session.messages));
    query.addBindValue(static_cast<int>(session.messages.size()));
    query.addBindValue(session.attachmentName.has_value() ? *session.attachmentName : QVariant());
    query.addBindValue(session.attachmentText.has_value() ? *session.attachmentText : QVariant());
    query.exec();
}

void ChatRepository::remove(const std::string& id) {
    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral("DELETE FROM AIChatSession WHERE id = ?"));
    query.addBindValue(q(id));
    query.exec();
}

} // namespace tick