using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;

namespace Tick.Services;

/// <summary>文档文本抽取错误</summary>
public class DocumentExtractionException : Exception
{
    public DocumentExtractionException(string message) : base(message) { }
}

/// <summary>
/// 从导入文档抽取纯文本（供 AI 生成任务清单）。
/// 支持纯文本 / Markdown（.txt / .md / .markdown）与 Word（.docx）。
/// 说明：PDF 文本抽取需第三方库（如 UglyToad.PdfPig），Windows 无内置文本层 API，
/// 本版本按需求聚焦「文本 / Markdown」附件，未引入该依赖。
/// </summary>
public static class DocumentTextExtractor
{
    private static readonly Regex ParagraphRegex =
        new("<w:p\\b[^>]*>(.*?)</w:p>", RegexOptions.Singleline | RegexOptions.Compiled);

    private static readonly Regex TextRunRegex =
        new("<w:t\\b[^>]*>(.*?)</w:t>", RegexOptions.Singleline | RegexOptions.Compiled);

    /// <summary>根据文档类型抽取文本（超出 maxLength 截断）</summary>
    public static string ExtractText(string path, int maxLength = 6000)
    {
        string ext = Path.GetExtension(path).TrimStart('.').ToLowerInvariant();
        string text = ext switch
        {
            "txt" or "md" or "markdown" or "text" or "" => ReadAsText(path),
            "docx" => ExtractDocx(path),
            "doc" => throw new DocumentExtractionException("旧版 .doc 暂不支持，请另存为 .docx 后重试"),
            "pdf" => throw new DocumentExtractionException("PDF 附件暂未启用（需文本抽取库）"),
            _ => throw new DocumentExtractionException("暂不支持该文件类型，请使用文本或 Markdown 文档"),
        };

        if (string.IsNullOrWhiteSpace(text))
            throw new DocumentExtractionException("未能从文档中读取到文字内容");

        return text.Length > maxLength ? text.Substring(0, maxLength) + "\n…" : text;
    }

    /// <summary>按多种编码尝试解析文本（UTF-8 → UTF-16 → GB18030/GBK），中文 txt 常为 GBK</summary>
    private static string ReadAsText(string path)
    {
        byte[] data = File.ReadAllBytes(path);
        foreach (var enc in CandidateEncodings())
        {
            try
            {
                var decoded = enc.GetString(data);
                // 仅接受看起来有效的解码（包含替换符 \uFFFD 的视为失败，继续尝试下一编码）
                if (!decoded.Contains('\uFFFD'))
                    return decoded;
            }
            catch (DecoderFallbackException)
            {
                // 继续尝试下一编码
            }
        }
        return Encoding.UTF8.GetString(data); // 宽松回退
    }

    private static IEnumerable<Encoding> CandidateEncodings()
    {
        yield return new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true);
        yield return Encoding.Unicode; // UTF-16 LE
        yield return Encoding.BigEndianUnicode; // UTF-16 BE
        try
        {
            // 需要 System.Text.Encoding.CodePages 注册（App 启动时 CodePagesEncodingProvider.Instance）
            yield return Encoding.GetEncoding("GB18030");
        }
        catch (ArgumentException)
        {
            // 未注册时跳过
        }
    }

    /// <summary>解析 docx（ZIP）并从 word/document.xml 抽取纯文本</summary>
    private static string ExtractDocx(string path)
    {
        using var zip = ZipFile.OpenRead(path);
        var entry = zip.GetEntry("word/document.xml");
        if (entry is null)
            throw new DocumentExtractionException("无法解析该 Word 文档");

        using var stream = entry.Open();
        using var reader = new StreamReader(stream, Encoding.UTF8);
        string xml = reader.ReadToEnd();
        return WordXmlText(xml);
    }

    /// <summary>从 document.xml 抽取文本：按 &lt;w:p&gt; 分段，段内拼接 &lt;w:t&gt; 内容</summary>
    private static string WordXmlText(string xml)
    {
        var lines = new List<string>();
        foreach (Match para in ParagraphRegex.Matches(xml))
        {
            string paragraph = para.Groups[1].Value;
            var chunks = new List<string>();
            foreach (Match t in TextRunRegex.Matches(paragraph))
                chunks.Add(t.Groups[1].Value);
            string line = string.Concat(chunks);
            if (!string.IsNullOrWhiteSpace(line))
                lines.Add(line);
        }
        return string.Join("\n", lines);
    }
}