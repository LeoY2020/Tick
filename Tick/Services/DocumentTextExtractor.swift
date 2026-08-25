import Foundation
import PDFKit
import Compression
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

    /// 入口：仅支持 .docx（ZIP 容器）；旧版 .doc 为二进制复合文档，无系统原生文本接口
    private static func extractWord(_ url: URL) throws -> String {
        guard url.pathExtension.lowercased() == "docx" else {
            throw ExtractionError.cannotReadWord
        }
        return try extractDOCX(url)
    }

    // MARK: - DOCX：ZIP 解析 + document.xml 文本抽取

    /// 解析 docx（ZIP）并返回 document.xml 中的纯文本。
    /// 只读取 OOXML 的 word/document.xml 条目，其余忽略。
    private static func extractDOCX(_ url: URL) throws -> String {
        guard let data = try? Data(contentsOf: url) else { throw ExtractionError.cannotReadWord }
        let bytes = [UInt8](data)
        guard bytes.count > 22 else { throw ExtractionError.cannotReadWord }

        // 1. 定位中央目录偏移（End of Central Directory 最后 22+ 字节，注释可能更长）
        guard let eocdIndex = findEOCD(bytes) else { throw ExtractionError.cannotReadWord }
        let cdOffset = Int(read32(bytes, eocdIndex + 16))

        // 2. 在中央目录查找 word/document.xml 条目
        var cursor = cdOffset
        var documentXML: (localOffset: Int, method: UInt16, compSize: Int, uncompSize: Int)?
        while cursor + 46 <= bytes.count {
            guard read32(bytes, cursor) == 0x02014b50 else { break }  // "PK\x01\x02"
            let method = read16(bytes, cursor + 10)
            let compSize = Int(read32(bytes, cursor + 20))
            let uncompSize = Int(read32(bytes, cursor + 24))
            let nameLen = Int(read16(bytes, cursor + 28))
            let extraLen = Int(read16(bytes, cursor + 30))
            let commentLen = Int(read16(bytes, cursor + 32))
            let localOffset = Int(read32(bytes, cursor + 42))
            let nameStart = cursor + 46
            guard nameStart + nameLen <= bytes.count else { break }
            let name = String(bytes: bytes[nameStart..<(nameStart + nameLen)], encoding: .utf8)
            if name == "word/document.xml" {
                documentXML = (localOffset, method, compSize, uncompSize)
                break
            }
            cursor = nameStart + nameLen + extraLen + commentLen
        }
        guard let entry = documentXML else { throw ExtractionError.cannotReadWord }

        // 3. 定位并读取压缩数据（经本地文件头计算数据起点）
        let local = entry.localOffset
        guard local + 30 <= bytes.count, read32(bytes, local) == 0x04034b50 else { throw ExtractionError.cannotReadWord }
        let localNameLen = Int(read16(bytes, local + 26))
        let localExtraLen = Int(read16(bytes, local + 28))
        let dataStart = local + 30 + localNameLen + localExtraLen
        let compSize = entry.compSize
        guard dataStart + compSize <= bytes.count else { throw ExtractionError.cannotReadWord }
        let compressed = bytes[dataStart..<(dataStart + compSize)]

        // 4. 解压（method 0 = 存储，8 = deflate）
        let xmlData: Data
        switch entry.method {
        case 0:
            xmlData = Data(compressed)
        case 8:
            guard let inflated = inflate(Array(compressed), expectedSize: entry.uncompSize) else {
                throw ExtractionError.cannotReadWord
            }
            xmlData = inflated
        default:
            throw ExtractionError.cannotReadWord
        }

        // 5. 抽取 <w:t> 文本，按 <w:p> 段落换行
        let text = wordXMLText(xmlData)
        guard !text.isEmpty else { throw ExtractionError.cannotReadWord }
        return text
    }

    /// 从尾部向前定位 EOCD 签名（0x06054b50）
    private static func findEOCD(_ bytes: [UInt8]) -> Int? {
        let sig: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        // 注释最长不超过 65535；从后往前找，至多扫描 sig.count + 65535 范围
        let searchStart = max(0, bytes.count - 22 - 65_535)
        if bytes.count < searchStart + sig.count { return nil }
        for i in stride(from: bytes.count - sig.count, through: searchStart, by: -1) {
            if Array(bytes[i..<(i + sig.count)]) == sig {
                return i
            }
        }
        return nil
    }

    /// 小端读取双字节
    private static func read16(_ b: [UInt8], _ o: Int) -> UInt16 {
        let hi = o + 1 < b.count ? UInt16(b[o + 1]) : 0
        let lo = o < b.count ? UInt16(b[o]) : 0
        return UInt16(lo | (hi << 8))
    }

    /// 小端读取四字节
    private static func read32(_ b: [UInt8], _ o: Int) -> UInt32 {
        var v: UInt32 = 0
        for i in 0..<4 where (o + i) < b.count {
            v |= UInt32(b[o + i]) << (8 * i)
        }
        return v
    }

    /// 用系统的 Compression 框架解压 deflate 数据（兼容 ZIP 的 raw deflate / zlib）
    private static func inflate(_ source: [UInt8], expectedSize: Int) -> Data? {
        // 防御：过大或过小都不合理
        guard expectedSize > 0, expectedSize < 100_000_000, !source.isEmpty else { return nil }
        var dst = [UInt8](repeating: 0, count: expectedSize)
        let written = dst.withUnsafeMutableBytes { dp -> Int in
            source.withUnsafeBytes { sp -> Int in
                compression_decode_buffer(dp.bindMemory(to: UInt8.self).baseAddress!,
                                          expectedSize,
                                          sp.bindMemory(to: UInt8.self).baseAddress!,
                                          source.count,
                                          nil,
                                          COMPRESSION_ZLIB)
            }
        }
        guard written == expectedSize else { return nil }
        return Data(dst)
    }

    /// 从 document.xml 抽取文本：按 <w:p> 分段，段内拼接 <w:t> 内容
    private static func wordXMLText(_ data: Data) -> String {
        guard let xml = String(data: data, encoding: .utf8) else { return "" }
        let paraPattern = try? NSRegularExpression(pattern: "<w:p\\b[^>]*>(.*?)</w:p>",
                                                   options: [.dotMatchesLineSeparators])
        let textPattern = try? NSRegularExpression(pattern: "<w:t\\b[^>]*>(.*?)</w:t>",
                                                   options: [.dotMatchesLineSeparators])
        guard let paraRegex = paraPattern, let textRegex = textPattern else { return "" }

        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        var lines: [String] = []
        paraRegex.enumerateMatches(in: xml, range: range) { match, _, _ in
            guard let match, let paramRange = Range(match.range(at: 1), in: xml) else { return }
            let paragraph = String(xml[paramRange])
            var chunks: [String] = []
            let pRange = NSRange(paragraph.startIndex..<paragraph.endIndex, in: paragraph)
            textRegex.enumerateMatches(in: paragraph, range: pRange) { tm, _, _ in
                guard let tm, let r = Range(tm.range(at: 1), in: paragraph) else { return }
                chunks.append(String(paragraph[r]))
            }
            let line = chunks.joined(separator: "")
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }
}

extension String {
    /// 返回截断后的字符串（长度不超过 max，超出以省略号结尾）
    fileprivate func clamped(to max: Int) -> String {
        guard count > max else { return self }
        return String(self[..<index(startIndex, offsetBy: max)]) + "\n…"
    }
}