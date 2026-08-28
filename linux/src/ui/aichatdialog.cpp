#include "ui/aichatdialog.h"

#include <QDialogButtonBox>
#include <QFileDialog>
#include <QFileInfo>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QTextBrowser>
#include <QVBoxLayout>

#include "services/aiservice.h"
#include "services/documenttextextractor.h"
#include "ui/translation.h"

namespace tick {

AIChatDialog::AIChatDialog(QWidget* parent)
    : QDialog(parent), ai_(new AIService(this)) {
    setModal(false);
    resize(520, 560);

    transcript_ = new QTextBrowser(this);
    transcript_->document()->setDefaultStyleSheet(QStringLiteral(
        "b.you{color:#007AFF;} b.ai{color:#34C759;} .body{color:inherit;}"));
    transcript_->setOpenExternalLinks(true);

    input_ = new QLineEdit(this);
    input_->setPlaceholderText(TR("描述你的任务 / 粘贴内容…", "Describe your tasks / paste content…"));

    sendBtn_ = new QPushButton(TR("发送", "Send"), this);
    attachBtn_ = new QPushButton(TR("添加附件", "Attach"), this);
    attachLabel_ = new QLabel(this);

    auto inputRow = new QHBoxLayout;
    inputRow->addWidget(input_);
    inputRow->addWidget(sendBtn_);

    auto buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    auto root = new QVBoxLayout(this);
    root->addWidget(transcript_, 1);
    root->addWidget(attachLabel_);
    auto attachRow = new QHBoxLayout;
    attachRow->addWidget(attachBtn_);
    attachRow->addStretch(1);
    root->addLayout(attachRow);
    root->addLayout(inputRow);
    root->addWidget(buttons);

    connect(sendBtn_, &QPushButton::clicked, this, &AIChatDialog::sendMessage);
    connect(input_, &QLineEdit::returnPressed, this, &AIChatDialog::sendMessage);
    connect(attachBtn_, &QPushButton::clicked, this, &AIChatDialog::chooseAttachment);
    connect(ai_, &AIService::finished, this, &AIChatDialog::onFinished);
    connect(ai_, &AIService::failed, this, &AIChatDialog::onFailed);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    reapplyLanguage();
}

void AIChatDialog::reapplyLanguage() {
    setWindowTitle(TR("AI 助手", "AI Assistant"));
    sendBtn_->setText(TR("发送", "Send"));
    attachBtn_->setText(TR("添加附件", "Attach"));
    input_->setPlaceholderText(TR("描述你的任务 / 粘贴内容…", "Describe your tasks / paste content…"));
}

QString AIChatDialog::systemPrompt() const {
    return AIService::chatSystemPrompt();
}

void AIChatDialog::appendMessage(const QString& who, const QString& text) {
    const QString esc = text.toHtmlEscaped().replace(QLatin1Char('\n'), QStringLiteral("<br/>"));
    transcript_->append(QStringLiteral("<b class=\"%1\">%2：</b><span class=\"body\">%3</span>")
                            .arg(who == QLatin1String("you") ? QStringLiteral("you") : QStringLiteral("ai"))
                            .arg(who.toHtmlEscaped())
                            .arg(esc));
}

void AIChatDialog::setWorking(bool working) {
    sendBtn_->setEnabled(!working);
    input_->setEnabled(!working);
    attachBtn_->setEnabled(!working);
}

void AIChatDialog::chooseAttachment() {
    const QString path = QFileDialog::getOpenFileName(
        this, TR("选择附件", "Select attachment"), QString(),
        TR("文本/Markdown/PDF (*.txt *.md *.markdown *.pdf);;所有文件 (*)", "Text/Markdown/PDF (*.txt *.md *.markdown *.pdf);;All files (*)"));
    if (path.isEmpty()) return;
    const auto result = DocumentTextExtractor::extractText(path);
    if (!result.ok) {
        QMessageBox::warning(this, TR("附件解析失败", "Attachment failed"), result.error);
        return;
    }
    QFileInfo fi(path);
    attachmentName_ = fi.fileName();
    attachmentText_ = result.text;
    attachLabel_->setText(TR("已附加：%1（%2 字符）", "Attached: %1 (%2 chars)")
                              .arg(attachmentName_)
                              .arg(attachmentText_.size()));
}

void AIChatDialog::sendMessage() {
    if (ai_->busy()) return;
    const QString text = input_->text().trimmed();
    if (text.isEmpty()) {
        input_->setFocus();
        return;
    }
    // 记录历史
    history_.append({ QStringLiteral("user"), text });
    appendMessage(TR("你", "You"), text);
    input_->clear();

    // 组装发送历史：附件正文作为首条用户消息注入
    QVector<AIMessage> payload = history_;
    const QString trimmed = attachmentText_.trimmed();
    if (!trimmed.isEmpty()) {
        payload.prepend({ QStringLiteral("user"),
                          QStringLiteral("附件内容：\n%1").arg(trimmed) });
    }

    setWorking(true);
    ai_->send(AIService::configFromSettings(), systemPrompt(), payload);
}

void AIChatDialog::onFinished(const QString& content) {
    setWorking(false);
    history_.append({ QStringLiteral("assistant"), content });

    const ChatReplyParse reply = AIService::parseChatReply(content);
    if (reply.shouldGenerateTask) {
        appendMessage(TR("助手", "Assistant"), reply.message);
        if (!reply.tasks.empty()) {
            emit generatedTasksReady(reply.tasks);
        } else {
            appendMessage(TR("助手", "Assistant"),
                          TR("（未能从回复解析出任务）", "(Could not parse tasks from reply)"));
        }
        attachmentText_.clear();
        attachmentName_.clear();
        attachLabel_->clear();
    } else {
        const QString text = reply.message.trimmed().isEmpty() ? content : reply.message;
        appendMessage(TR("助手", "Assistant"), text);
    }
}

void AIChatDialog::onFailed(const QString& error) {
    setWorking(false);
    appendMessage(TR("错误", "Error"), error);
}

} // namespace tick