package com.tick.app.android.doc

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import java.io.File
import java.nio.charset.Charset
import java.util.Locale

/**
 * 从导入的文档抽取纯文本（供 AI 生成任务清单）。
 * 支持：纯文本 / Markdown（.txt / .md / .markdown / .text）、PDF（文本型）。
 * PDF 文本提取失败（如扫描件无文本层、加密等）时抛出友好提示，不崩溃。
 */
object DocumentTextExtractor {

    sealed class ExtractionError(message: String) : Exception(message) {
        object CannotReadText : ExtractionError("无法读取该文件的文本内容（仅支持文本 / Markdown / PDF 格式）")
        object EmptyText : ExtractionError("文件中没有可识别的文字内容")
        object PdfExtractionFailed : ExtractionError(
            "未能从该 PDF 提取文字：可能是扫描件（无文字层）或已加密，请改用带文字的 PDF 或文本文件"
        )
    }

    /**
     * 从 Uri 读取文本内容。
     * @param maxLength 抽取文本的最大字符数（超出截断，避免超出模型上下文）
     */
    fun extractText(context: Context, uri: Uri, maxLength: Int = 6000): String {
        return if (isPdf(context, uri)) {
            extractPdf(context, uri, maxLength)
        } else {
            extractPlain(context, uri, maxLength)
        }
    }

    // MARK: - 纯文本 / Markdown

    private fun extractPlain(context: Context, uri: Uri, maxLength: Int): String {
        val bytes = try {
            context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (e: Exception) {
            null
        } ?: throw ExtractionError.CannotReadText
        val text = decode(bytes)
        val trimmed = text.trim()
        if (trimmed.isEmpty()) throw ExtractionError.EmptyText
        return clamp(trimmed, maxLength)
    }

    private fun decode(bytes: ByteArray): String {
        if (bytes.isEmpty()) return ""
        runCatching { return String(bytes, Charsets.UTF_8) }
        runCatching { return String(bytes, Charsets.UTF_16) }
        runCatching { return String(bytes, Charset.forName("GB18030")) }
        throw ExtractionError.CannotReadText
    }

    // MARK: - PDF

    private fun extractPdf(context: Context, uri: Uri, maxLength: Int): String {
        try {
            PDFBoxResourceLoader.init(context.applicationContext)
            val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw ExtractionError.CannotReadText
            val temp = File(context.cacheDir, "tick_attachment_${System.currentTimeMillis()}.pdf")
            temp.writeBytes(bytes)
            val text = try {
                PDDocument.load(temp).use { doc ->
                    val stripper = PDFTextStripper()
                    stripper.startPage = 1
                    stripper.endPage = doc.numberOfPages
                    stripper.text
                }
            } finally {
                temp.delete()
            }
            val trimmed = text.trim()
            if (trimmed.isEmpty()) throw ExtractionError.PdfExtractionFailed
            return clamp(trimmed, maxLength)
        } catch (e: ExtractionError) {
            throw e
        } catch (e: Exception) {
            throw ExtractionError.PdfExtractionFailed
        }
    }

    // MARK: - 判断

    private fun isPdf(context: Context, uri: Uri): Boolean {
        val mime = context.contentResolver.getType(uri)?.lowercase(Locale.ROOT) ?: ""
        if (mime.contains("pdf")) return true
        val name = queryDisplayName(context, uri)?.lowercase(Locale.ROOT) ?: ""
        val ext = name.substringAfterLast('.', "")
        return ext == "pdf"
    }

    private fun queryDisplayName(context: Context, uri: Uri): String? {
        return try {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { c ->
                    if (c.moveToFirst()) c.getString(0) else null
                }
        } catch (e: Exception) {
            null
        }
    }

    private fun clamp(text: String, max: Int): String =
        if (text.length <= max) text else text.substring(0, max) + "\n…"
}