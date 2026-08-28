import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import { SettingsModel } from '../model/Settings';
import { SettingsStore } from '../data/Repositories';
import { I18n } from '../model/I18n';
import { BackupService } from '../services/BackupService';
import { Theme, ThemePalette, DesignTokens } from '../theme/DesignTokens';

const D = DesignTokens;

/** 设置页：配色 / 语言 / AI 配置 / JSON 备份 */
@Entry
@Component
struct Settings {
  build() {
    this.page()
  }

  @Builder
  page() {
    Column() {
      // 顶部栏
      Row() {
        Button(I18n.L('‹ 返回', '‹ Back'))
          .fontSize(D.fontSizeBody2)
          .fontColor(this.tPrimary())
          .backgroundColor(Color.Transparent)
          .onClick(() => router.back())
        Blank()
        Text(I18n.L('设置', 'Settings'))
          .fontSize(D.fontSizeTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tPrimary())
      }.width('100%').padding({ left: D.spaceMd, right: D.spaceMd, top: D.spaceMd, bottom: D.spaceSm })

      Scroll() {
        Column({ space: D.spaceLg }) {
          this.sectionTitle(I18n.L('外观', 'Appearance'))
          this.colorSchemeSection()

          this.sectionTitle(I18n.L('语言', 'Language'))
          this.languageSection()

          this.sectionTitle(I18n.L('AI 助手', 'AI Assistant'))
          this.aiSection()

          this.sectionTitle(I18n.L('备份', 'Backup'))
          this.backupSection()

          this.xiaoyiNote()
        }
        .width('100%')
        .padding({ left: D.spaceLg, right: D.spaceLg, bottom: D.spaceXxl })
        .constraintSize({ maxHeight: 10000 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg())
  }

  @Builder
  sectionTitle(t: string) {
    Text(t)
      .fontSize(D.fontSizeCaption)
      .fontColor(this.tSecondary())
      .width('100%')
      .margin({ top: D.spaceSm })
  }

  @Builder
  colorSchemeSection() {
    Row({ space: D.spaceSm }) {
      this.schemeChip('system', I18n.L('跟随系统', 'System'))
      this.schemeChip('light', I18n.L('亮色', 'Light'))
      this.schemeChip('dark', I18n.L('暗色', 'Dark'))
    }.width('100%')
  }

  @Builder
  schemeChip(v: 'system' | 'light' | 'dark', label: string) {
    Text(label)
      .fontSize(D.fontSizeBody2)
      .fontColor(this.m.colorScheme === v ? Color.White : this.tPrimary())
      .backgroundColor(this.m.colorScheme === v ? D.colorPrimary : this.colorPressed())
      .padding({ left: D.spaceLg, right: D.spaceLg, top: D.spaceSm, bottom: D.spaceSm })
      .borderRadius(D.radiusPill)
      .onClick(() => this.applyColorScheme(v))
  }

  @Builder
  languageSection() {
    Row({ space: D.spaceSm }) {
      this.langChip('system', I18n.L('跟随系统', 'System'))
      this.langChip('zh', '简体中文')
      this.langChip('en', 'English')
    }.width('100%')
  }

  @Builder
  langChip(v: 'system' | 'zh' | 'en', label: string) {
    Text(label)
      .fontSize(D.fontSizeBody2)
      .fontColor(this.m.language === v ? Color.White : this.tPrimary())
      .backgroundColor(this.m.language === v ? D.colorPrimary : this.colorPressed())
      .padding({ left: D.spaceLg, right: D.spaceLg, top: D.spaceSm, bottom: D.spaceSm })
      .borderRadius(D.radiusPill)
      .onClick(() => this.applyLanguage(v))
  }

  @Builder
  aiSection() {
    Column({ space: D.spaceMd }) {
      this.fieldLabel(I18n.L('OpenAI 兼容 Base URL', 'OpenAI compatible Base URL'))
      TextInput({ text: this.m.baseUrl, placeholder: 'https://api.deepseek.com/v1' })
        .height(42)
        .borderRadius(D.radiusM)
        .backgroundColor(this.card())
        .fontColor(this.tPrimary())
        .onChange((v: string) => { this.m.baseUrl = v })
      this.fieldLabel(I18n.L('模型名', 'Model name'))
      TextInput({ text: this.m.modelName, placeholder: 'deepseek-chat' })
        .height(42)
        .borderRadius(D.radiusM)
        .backgroundColor(this.card())
        .fontColor(this.tPrimary())
        .onChange((v: string) => { this.m.modelName = v })
      this.fieldLabel(I18n.L('API Key', 'API Key'))
      TextInput({ text: this.m.apiKey, placeholder: 'sk-...' })
        .type(InputType.Password)
        .height(42)
        .borderRadius(D.radiusM)
        .backgroundColor(this.card())
        .fontColor(this.tPrimary())
        .onChange((v: string) => { this.m.apiKey = v })
      Button(I18n.L('保存 AI 配置', 'Save AI Config'))
        .width('100%')
        .height(42)
        .borderRadius(D.radiusL)
        .backgroundColor(D.colorPrimary)
        .fontColor(Color.White)
        .onClick(() => this.saveSettings())
    }
  }

  @Builder
  backupSection() {
    Column({ space: D.spaceMd }) {
      Button(I18n.L('导出备份到 Download', 'Export backup to Download'))
        .width('100%')
        .height(42)
        .borderRadius(D.radiusL)
        .backgroundColor(D.colorPrimary)
        .fontColor(Color.White)
        .onClick(() => this.exportBackup())
      Button(I18n.L('导入备份', 'Import backup'))
        .width('100%')
        .height(42)
        .borderRadius(D.radiusL)
        .backgroundColor(this.colorPressed())
        .fontColor(this.tPrimary())
        .onClick(() => this.importBackup())
    }
  }

  @Builder
  xiaoyiNote() {
    Column({ space: 6 }) {
      Text(I18n.L('小艺助手', 'Xiaoyi Assistant'))
        .fontSize(D.fontSizeBody2)
        .fontColor(this.tPrimary())
        .width('100%')
      Text(I18n.L('小艺（盘古）无公开第三方 API，需华为开发者资质与其移动服务授权后方可内嵌。当前通过上方 OpenAI 兼容 API 提供 AI 能力。',
        'Xiaoyi (Pangu) has no public third-party API and requires Huawei developer credentials to integrate. AI is currently provided through the OpenAI-compatible API above.'))
        .fontSize(D.fontSizeCaption)
        .fontColor(this.tSecondary())
        .width('100%')
        .lineHeight(20)
    }
    .width('100%')
    .padding(D.spaceMd)
    .borderRadius(D.radiusM)
    .backgroundColor(this.card())
    .margin({ top: D.spaceMd })
  }

  @Builder
  fieldLabel(t: string) {
    Text(t)
      .fontSize(D.fontSizeCaption)
      .fontColor(this.tSecondary())
      .width('100%')
  }

  // ===== 状态与数据 =====
  @State m: SettingsModel = new SettingsModel()
  @State exporting: boolean = false
  @State importing: boolean = false

  aboutToAppear(): void {
    this.load()
  }

  async load(): Promise<void> {
    this.m = await SettingsStore.load()
    I18n.setLanguage(this.m.language)
  }

  async applyColorScheme(v: 'system' | 'light' | 'dark'): Promise<void> {
    this.m.colorScheme = v
    await this.saveSettings()
  }

  async applyLanguage(v: 'system' | 'zh' | 'en'): Promise<void> {
    this.m.language = v
    I18n.setLanguage(v)
    await this.saveSettings()
  }

  async saveSettings(): Promise<void> {
    await SettingsStore.save(this.m)
    promptAction.showToast({ message: I18n.L('已保存', 'Saved') })
  }

  async exportBackup(): Promise<void> {
    if (this.exporting) {
      return
    }
    this.exporting = true
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      const path = await BackupService.export(ctx)
      promptAction.showToast({ message: I18n.L('已导出', 'Exported') + path })
    } catch (e) {
      promptAction.showToast({ message: I18n.L('导出失败', 'Export failed') })
    } finally {
      this.exporting = false
    }
  }

  async importBackup(): Promise<void> {
    if (this.importing) {
      return
    }
    try {
      const hostCtx = this.getUIContext().getHostContext()
      if (hostCtx === undefined) {
        promptAction.showToast({ message: I18n.L('无法读取文件', 'Cannot pick file') })
        return
      }
      const documentPicker = new picker.DocumentViewPicker(hostCtx as common.Context)
      const result = await documentPicker.select({ maxSelectNumber: 1 })
      const uriList: string[] = result.uri
      const uri = (uriList !== undefined && uriList !== null && uriList.length > 0) ? uriList[0] : ''
      if (uri === undefined || uri.length === 0) {
        return
      }
      this.importing = true
      const ctx = hostCtx as common.UIAbilityContext
      const count = await BackupService.import(ctx, uri)
      promptAction.showToast({ message: I18n.L(`已导入 ${count} 个目标`, `Imported ${count} goals`) })
    } catch (e) {
      promptAction.showToast({ message: I18n.L('导入失败', 'Import failed') })
    } finally {
      this.importing = false
    }
  }

  // ===== 主题辅助 =====
  private isDark(): boolean {
    return Theme.dark(this.m.colorScheme)
  }

  private pal(): ThemePalette {
    return Theme.palette(this.isDark())
  }

  private bg(): string {
    return this.pal().bg
  }

  private card(): string {
    return this.pal().card
  }

  private tPrimary(): string {
    return this.pal().textPrimary
  }

  private tSecondary(): string {
    return this.pal().textSecondary
  }

  private colorPressed(): string {
    return this.isDark() ? '#33FFFFFF' : '#0D000000'
  }
}