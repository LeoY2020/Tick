#pragma once

#include <QString>

namespace tick {

// 从附件（文本 / Markdown / PDF）抽取纯文本，供 AI 生成任务清单使用。
// - .txt / .md / .markdown / .text：直接按编码解析
// - .pdf：调用系统 pdftotext 命令抽取（失败时给出友好提示）
class DocumentTextExtractor {
public:
    struct Result {
        bool ok = false;
        QString text;
        QString error;
    };

    /// 支持 .txt / .md / .markdown / .text / .pdf（超出 maxLength 截断）
    static Result extractText(const QString& filePath, int maxLength = 6000);

    /// 支持的扩展名（小写）
    static bool isSupported(const QString& filePath);

private:
    static Result readAsText(const QString& filePath, int maxLength);
    static Result extractPDF(const QString& filePath, int maxLength);
    static QString clamp(const QString& text, int maxLength);
};

} // namespace tick