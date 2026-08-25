import Foundation
import PDFKit
import UniformTypeIdentifiers

/// 从导入文档抽取纯文本（供 AI 生成任务清单），支持：
/// - 纯文本 / Markdown（.txt / .md / .markdown）
/// - PDF（.pdf，用 PDFKit 逐页抽取）
/// - Word（.doc / .docx，用 NSAttributedString 解析器）
enum DocumentTextExtractor {

    /// 文本抽取错误
    enum ExtractionError: LocalizedError {
        case unsupportedType
        case cannotReadText
        case cannotReadPDF
        case cannotReadWord

        var errorDescription: String? {
            switch self {
            case .unsupportedType: return "暂不支持该文件类型，请使用文本、Markdown、PDF 或 Word 文档"
            case .cannotReadText: return "无法读取文本内容"
            case .cannotReadPDF: return "无法解析 PDF 内容"
            case .cannotReadWord: return "无法解析 Word 文档"
            }
        }
    }

    /// 根据文档类型抽取文本
    /// - Parameters:
    ///   - url: 文档本地 URL
    ///   - maxLength: 抽取文本的最大字符数（超出截断，避免超出模型上下文）
    /// - Returns: 抽取后的文本（非空才返回）
    static func extractText(from url: URL, maxLength: Int = 6000) throws -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "txt", "md", "markdown", "text", "":
            return try readAsUTF8(url).clamped(to: maxLength)
        case "pdf":
            return try extractPDF(url).clamped(to: maxLength)
        case "doc", "docx":
            return try extractWord(url).clamped(to: maxLength)
        default:
            throw ExtractionError.unsupportedType
        }
    }

    // MARK: - 各类型实现

    private static func readAsUTF8(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ExtractionError.cannotReadText
        }
        return text
    }

    private static func extractPDF(_ url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ExtractionError.cannotReadPDF
        }
        guard let text = document.string, !text.isEmpty else {
            throw ExtractionError.cannotReadPDF
        }
        return text
    }

    private static func extractWord(_ url: URL) throws -> String {
        guard let data = try? Data(contentsOf: url) else {
            throw ExtractionError.cannotReadWord
        }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.officeOpenXML,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            throw ExtractionError.cannotReadWord
        }
        let text = attributed.string
        guard !text.isEmpty else { throw ExtractionError.cannotReadWord }
        return text
    }
}

extension String {
    /// 返回截断后的字符串（长度不超过 max，超出以省略号结尾）
    fileprivate func clamped(to max: Int) -> String {
        guard count > max else { return self }
        return String(self[..<index(startIndex, offsetBy: max)]) + "\n…"
    }
}