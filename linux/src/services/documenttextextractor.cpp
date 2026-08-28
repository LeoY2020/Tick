#include "services/documenttextextractor.h"

#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStringConverter>
#include <QStringList>

namespace tick {

bool DocumentTextExtractor::isSupported(const QString& filePath) {
    const QString ext = QFileInfo(filePath).suffix().toLower();
    return ext == QLatin1String("txt") || ext == QLatin1String("md") ||
           ext == QLatin1String("markdown") || ext == QLatin1String("text") ||
           ext == QLatin1String("pdf") || ext.isEmpty();
}

QString DocumentTextExtractor::clamp(const QString& text, int maxLength) {
    if (text.size() <= maxLength) return text;
    return text.left(maxLength) + QStringLiteral("\n…");
}

DocumentTextExtractor::Result DocumentTextExtractor::readAsText(const QString& filePath, int maxLength) {
    Result r;
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) {
        r.error = QStringLiteral("无法读取文本内容（请确认文件可读）");
        return r;
    }
    const QByteArray bytes = f.readAll();

    auto decode = [&bytes](QStringConverter::Encoding enc, QString& out) {
        QStringDecoder decoder(enc);
        out = decoder.decode(bytes);
        return !decoder.hasError();
    };

    QString text;
    // UTF-8 优先
    if (decode(QStringConverter::Utf8, text)) {
        r.ok = true;
        r.text = clamp(text, maxLength);
        return r;
    }
    // GB18030 / GBK（中文 txt 常见编码）
    if (auto enc = QStringConverter::encodingForName(QStringLiteral("GB18030"))) {
        if (decode(*enc, text)) {
            r.ok = true;
            r.text = clamp(text, maxLength);
            return r;
        }
    }
    // UTF-16（含 BOM）
    if (decode(QStringConverter::Utf16, text)) {
        r.ok = true;
        r.text = clamp(text, maxLength);
        return r;
    }

    r.error = QStringLiteral("无法识别文件编码（请使用 UTF-8 编码保存后重试）");
    return r;
}

DocumentTextExtractor::Result DocumentTextExtractor::extractPDF(const QString& filePath, int maxLength) {
    Result r;
    // 调用系统 pdftotext（poppler-utils），抽取带版式布局的文本
    QProcess process;
    process.start(QStringLiteral("pdftotext"), QStringList() << QStringLiteral("-layout") << filePath
                                                             << QStringLiteral("-"));
    if (!process.waitForFinished(15000)) {
        process.kill();
        process.waitForFinished(1000);
        r.error = QStringLiteral("无法解析 PDF 内容（请确认系统已安装 poppler-utils）");
        return r;
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        r.error = QStringLiteral("无法解析 PDF 内容（可能是扫描件，无文字层可提取）");
        return r;
    }
    const QByteArray out = process.readAllStandardOutput();
    // 尝试按编码解码
    auto decode = [&out](QStringConverter::Encoding enc, QString& s) {
        QStringDecoder decoder(enc);
        s = decoder.decode(out);
        return !decoder.hasError();
    };
    QString text;
    if (decode(QStringConverter::Utf8, text)) {
        r.ok = true;
        r.text = clamp(text, maxLength);
        return r;
    }
    if (auto enc = QStringConverter::encodingForName(QStringLiteral("GB18030"))) {
        if (decode(*enc, text)) {
            r.ok = true;
            r.text = clamp(text, maxLength);
            return r;
        }
    }
    r.error = QStringLiteral("无法解析 PDF 文本编码");
    return r;
}

DocumentTextExtractor::Result DocumentTextExtractor::extractText(const QString& filePath, int maxLength) {
    const QString ext = QFileInfo(filePath).suffix().toLower();
    if (ext == QLatin1String("pdf")) {
        return extractPDF(filePath, maxLength);
    }
    if (isSupported(filePath)) {
        return readAsText(filePath, maxLength);
    }
    Result r;
    r.error = QStringLiteral("暂不支持该文件类型，请使用文本、Markdown 或 PDF 文档");
    return r;
}

} // namespace tick