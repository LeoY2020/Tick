#pragma once

#include <QDialog>
#include <QVector>

#include <memory>
#include <vector>

#include "services/aiservice.h"

class QLabel;
class QLineEdit;
class QPlainTextEdit;
class QPushButton;
class QTextBrowser;

namespace tick {

class AIService;

// AI 聊天对话框：多轮对话 + 附件解析 + 生成任务。
// 生成到的任务通过 emitted generatedTasksReady 交由主界面写入当前目标。
class AIChatDialog : public QDialog {
    Q_OBJECT
public:
    explicit AIChatDialog(QWidget* parent = nullptr);

    void reapplyLanguage();

signals:
    /// 模型生成的任务树（需写入当前选中目标）
    void generatedTasksReady(const std::vector<std::shared_ptr<GeneratedTask>>& tasks);

private slots:
    void sendMessage();
    void chooseAttachment();
    void onFinished(const QString& content);
    void onFailed(const QString& error);

private:
    void appendMessage(const QString& who, const QString& text);
    void setWorking(bool working);
    QString systemPrompt() const;

    QTextBrowser* transcript_ = nullptr;
    QLineEdit* input_ = nullptr;
    QPushButton* sendBtn_ = nullptr;
    QPushButton* attachBtn_ = nullptr;
    QLabel* attachLabel_ = nullptr;

    AIService* ai_ = nullptr;
    QVector<AIMessage> history_;
    QString attachmentText_;
    QString attachmentName_;
};

} // namespace tick