import fs from '@ohos.file.fs';
import { fileUri } from '@ohos.file.fileuri';
import { I18n } from '../model/I18n';

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
        throw new Error(I18n.t('doc.error.unsupportedFormat'));
      default:
        throw new Error(I18n.t('doc.error.unsupportedType'));
    }
  }

  private static async readAsText(path: string): Promise<string> {
    try {
      const text = await fs.readText(path);
      if (text.trim().length === 0) {
        throw new Error(I18n.t('doc.error.readEmpty'));
      }
      return text;
    } catch (e) {
      throw new Error(I18n.t('doc.error.readFailed'));
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