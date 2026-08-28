#include "services/aiservice.h"

#include <QJsonDocument>
#include <QJsonValue>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStringList>
#include <QUrl>

#include "data/settingsrepository.h"

namespace tick {

namespace {

// 抽取文本中第一个 '{' 到最后一个 '}' 的 JSON 对象子串（容忍模型附加的零散文字）
QString jsonObjectFrom(const QString& text) {
    const int start = text.indexOf(QLatin1Char('{'));
    const int end = text.lastIndexOf(QLatin1Char('}'));
    if (start < 0 || end < 0 || start >= end) return QString();
    return text.mid(start, end - start + 1);
}

// 去掉 ``` 代码围栏（模型有时会把 JSON 包进 Markdown 代码块）
QString stripCodeFences(QString text) {
    QStringList lines = text.split(QLatin1Char('\n'));
    if (!lines.isEmpty() && lines.first().contains(QStringLiteral("```"))) {
        lines.removeFirst();
    }
    if (!lines.isEmpty() && lines.last().contains(QStringLiteral("```"))) {
        lines.removeLast();
    }
    return lines.join(QLatin1Char('\n'));
}

} // namespace

std::shared_ptr<GeneratedTask> GeneratedTask::fromJson(const QJsonValue& value) {
    auto node = std::make_shared<GeneratedTask>();
    if (value.isObject()) {
        const QJsonObject o = value.toObject();
        node->name = o.value(QStringLiteral("name")).toString();
        appendFromArray(o.value(QStringLiteral("children")), node->children);
    } else if (value.isString()) {
        node->name = value.toString();
    }
    return node;
}

void GeneratedTask::appendFromArray(const QJsonValue& value, std::vector<std::shared_ptr<GeneratedTask>>& out) {
    if (!value.isArray()) return;
    const QJsonArray arr = value.toArray();
    for (const QJsonValue& v : arr) {
        out.push_back(fromJson(v));
    }
}

// 聊天系统提示词：输出 JSON envelope（任务入库 + 展示文字），严禁生成空泛任务
QString AIService::chatSystemPrompt() {
    return QStringLiteral(
        "你是一个严谨的中文任务规划助手。你可以依据以下两类信息来生成具体、可执行、有信息量的分层任务清单：\n"
        "1. 文档附件内容（通常在用户消息的\"附件内容：\"之后）：从中提炼真实要点建任务，按章节、核心观点、待办事项拆分。\n"
        "2. 用户在对话中描述的任务与计划：即使没有附件，也依据对话上下文，把用户提出的需求、事项、时间安排等整理成分层任务树。\n"
        "\n"
        "硬性要求：\n"
        "1. 任务名要具体明确（如\"核对第三章数据\"\"完成市场分析草稿\"），严禁生成\"了解xxx\"\"阅读附件\"\"整理要点\"这类空泛无信息的任务。\n"
        "2. 一级任务概括主题，二级任务给出具体动作或子步骤，层级嵌套。\n"
        "3. 只要用户明确要求\"生成/整理任务\"（无论仅提供附件、还是仅在对话中描述需求），都应 generate=true 并基于可用信息生成任务树。\n"
        "4. 仅当既没有附件正文、也没有明确的对话需求、实在无法提炼时，才返回 generate=false 并说明原因。\n"
        "\n"
        "你必须严格只输出一个 JSON 对象，不要输出 markdown 代码块，也不要输出 JSON 以外的任何文字：\n"
        "1. 用户要求生成/整理任务且能提炼要点时，输出：\n"
        "{\"generate\": true, \"tasks\": [{\"name\":\"一级任务\",\"children\":[{\"name\":\"二级任务\"}]}], \"message\": \"给用户看的一句话中文说明\"}\n"
        "2. 用户要求生成任务、但既无附件正文也无明确对话需求、无法生成有意义任务时，输出：\n"
        "{\"generate\": false, \"message\": \"我目前还缺少足够的信息来生成有意义的任务。你可以上传带文字的 PDF / 文本，或在对话里描述你想规划的事项。\"}\n"
        "3. 其他普通闲聊（未要求生成任务）时，输出：\n"
        "{\"generate\": false, \"message\": \"你的回复文字\"}\n");
}

ChatReplyParse AIService::parseChatReply(const QString& raw) {
    ChatReplyParse out;
    const QString cleaned = stripCodeFences(raw).trimmed();
    const QString objectText = jsonObjectFrom(cleaned);
    if (!objectText.isEmpty()) {
        const QJsonDocument doc = QJsonDocument::fromJson(objectText.toUtf8());
        if (doc.isObject()) {
            const QJsonObject root = doc.object();
            const bool generate = root.value(QStringLiteral("generate")).toBool(false);
            if (generate) {
                out.shouldGenerateTask = true;
                GeneratedTask::appendFromArray(root.value(QStringLiteral("tasks")), out.tasks);
                // 过滤空名任务
                for (auto it = out.tasks.begin(); it != out.tasks.end();) {
                    if ((*it)->name.trimmed().isEmpty()) it = out.tasks.erase(it);
                    else ++it;
                }
                out.message = root.value(QStringLiteral("message")).toString();
                if (out.message.trimmed().isEmpty()) {
                    out.message = QStringLiteral("已为你生成 %1 个任务。").arg(out.tasks.size());
                }
                return out;
            }
            const QString msg = root.value(QStringLiteral("message")).toString();
            if (!msg.trimmed().isEmpty()) {
                out.message = msg;
                return out;
            }
        }
    }
    // 宽容回退：把原文当普通文字展示
    out.message = raw;
    return out;
}

AIService::AIService(QObject* parent) : QObject(parent) {}

AIService::~AIService() {
    if (reply_) {
        reply_->abort();
        reply_->deleteLater();
        reply_ = nullptr;
    }
}

bool AIService::busy() const {
    return reply_ != nullptr;
}

AIConfig AIService::configFromSettings() {
    SettingsRepository repo;
    AIConfig c;
    c.provider = repo.aiProvider();
    c.apiKey = repo.apiKey();
    const QString base = repo.baseUrl();
    c.baseUrl = base.isEmpty() ? aiProviderBaseUrl(c.provider) : base;
    const QString model = repo.modelName();
    c.modelName = model.isEmpty() ? aiProviderDefaultModel(c.provider) : model;
    return c;
}

QString AIService::endpointUrl(const QString& baseUrl) const {
    QString base = baseUrl.simplified();
    if (base.endsWith(QStringLiteral("/chat/completions"))) {
        return base;
    }
    while (base.endsWith(QLatin1Char('/'))) {
        base.chop(1);
    }
    return base + QStringLiteral("/chat/completions");
}

void AIService::send(const AIConfig& config, const QString& systemPrompt,
                     const QVector<AIMessage>& history) {
    if (reply_) {
        reply_->abort();
        reply_->deleteLater();
        reply_ = nullptr;
    }
    if (config.apiKey.trimmed().isEmpty()) {
        emit failed(QStringLiteral("请前往设置填写 API Key"));
        return;
    }
    if (config.baseUrl.trimmed().isEmpty()) {
        emit failed(QStringLiteral("请前往设置填写 Base URL"));
        return;
    }

    QJsonObject root;
    root.insert(QStringLiteral("model"), config.modelName);

    QJsonArray messages;
    QJsonObject sys;
    sys.insert(QStringLiteral("role"), QStringLiteral("system"));
    sys.insert(QStringLiteral("content"), systemPrompt);
    messages.append(sys);
    for (const auto& m : history) {
        QJsonObject o;
        o.insert(QStringLiteral("role"), m.role);
        o.insert(QStringLiteral("content"), m.content);
        messages.append(o);
    }
    root.insert(QStringLiteral("messages"), messages);

    QNetworkRequest request(QUrl(endpointUrl(config.baseUrl)));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Authorization", QStringLiteral("Bearer %1").arg(config.apiKey).toUtf8());

    reply_ = manager_.post(request, QJsonDocument(root).toJson(QJsonDocument::Compact));
    connect(reply_, &QNetworkReply::finished, this, &AIService::onReplyFinished);
}

void AIService::onReplyFinished() {
    QNetworkReply* r = reply_;
    if (!r) return;
    reply_ = nullptr;

    const QByteArray data = r->readAll();
    const QString netError = r->errorString();
    const int httpStatus =
        r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    r->deleteLater();

    if (r->error() != QNetworkReply::NoError) {
        emit failed(QStringLiteral("网络请求失败：%1（HTTP %2）").arg(netError).arg(httpStatus));
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        emit failed(QStringLiteral("模型服务返回了异常响应"));
        return;
    }
    const QJsonObject root = doc.object();
    const QJsonArray choices = root.value(QStringLiteral("choices")).toArray();
    if (choices.isEmpty()) {
        emit failed(QStringLiteral("模型服务返回了异常响应"));
        return;
    }
    const QJsonObject message = choices.first().toObject().value(QStringLiteral("message")).toObject();
    const QString content = message.value(QStringLiteral("content")).toString();
    if (content.trimmed().isEmpty()) {
        emit failed(QStringLiteral("模型未生成有效内容"));
        return;
    }
    emit finished(content);
}

} // namespace tick