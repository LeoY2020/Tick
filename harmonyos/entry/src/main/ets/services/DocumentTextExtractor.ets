import fs from '@ohos.file.fs';
import { fileUri } from '@ohos.file.fileuri';

/**
 * 从导入的附件文档抽取纯文本（供 AI 生成任务清单）。
 * HarmonyOS 版本支持：纯文本 / Markdown（.txt / .md / .markdown / .text）。
 * PDF / Word 需引入第三方解析库，当前返回明确报错。
 */
export class DocumentTextExtractor {
  static async extractText(uriOrPath: string, maxLength: number = 6000): Promise<string> {
    let path = uriOrPath;
    if (path.startsWith('file://')) {
      path = new fileUri.FileUri(path).path;
    }
    const ext = DocumentTextExtractor.extensionOf(path);
    switch (ext) {
      case 'txt':
      case 'md':
      case 'markdown':
      case 'text':
      case '': {
        const text = await DocumentTextExtractor.readAsText(path);
        return DocumentTextExtractor.clamp(text, maxLength);
      }
      case 'pdf':
      case 'doc':
      case 'docx':
        throw new Error('当前版本暂仅支持文本 / Markdown 附件（PDF / Word 需第三方解析库）');
      default:
        throw new Error('暂不支持该文件类型，请使用文本或 Markdown 文档');
    }
  }

  private static async readAsText(path: string): Promise<string> {
    try {
      const text = await fs.readText(path);
      if (text.trim().length === 0) {
        throw new Error('无法读取文本内容（文件为空或非文本格式）');
      }
      return text;
    } catch (e) {
      throw new Error('无法读取文本内容（请确认文件为 UTF-8 文本 / Markdown 格式）');
    }
  }

  private static extensionOf(path: string): string {
    const idx = path.lastIndexOf('.');
    if (idx < 0) {
      return '';
    }
    return path.substring(idx + 1).toLowerCase();
  }

  private static clamp(text: string, max: number): string {
    if (text.length <= max) {
      return text;
    }
    return text.substring(0, max) + '\n…';
  }
}