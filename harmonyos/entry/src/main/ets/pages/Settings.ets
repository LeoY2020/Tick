import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import { SettingsModel } from '../model/Settings';
import { SettingsStore } from '../data/Repositories';
import { I18n } from '../model/I18n';
import { LanguageSetting } from '../model/Enums';
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
        Button(I18n.all({ zh: '‹ 返回', zhHant: '‹ 返回', ja: '‹ 戻る', ko: '‹ 뒤로', en: '‹ Back', fr: '‹ Retour', de: '‹ Zurück', es: '‹ Atrás' }))
          .fontSize(D.fontSizeBody2)
          .fontColor(this.tPrimary())
          .backgroundColor(Color.Transparent)
          .onClick(() => router.back())
        Blank()
        Text(I18n.all({ zh: '设置', zhHant: '設定', ja: '設定', ko: '설정', en: 'Settings', fr: 'Réglages', de: 'Einstellungen', es: 'Ajustes' }))
          .fontSize(D.fontSizeTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tPrimary())
      }.width('100%').padding({ left: D.spaceMd, right: D.spaceMd, top: D.spaceMd, bottom: D.spaceSm })

      Scroll() {
        Column({ space: D.spaceLg }) {
          this.sectionTitle(I18n.all({ zh: '外观', zhHant: '外觀', ja: '外観', ko: '화면 모드', en: 'Appearance', fr: 'Apparence', de: 'Darstellung', es: 'Apariencia' }))
          this.colorSchemeSection()

          this.sectionTitle(I18n.all({ zh: '语言', zhHant: '語言', ja: '言語', ko: '언어', en: 'Language', fr: 'Langue', de: 'Sprache', es: 'Idioma' }))
          this.languageSection()

          this.sectionTitle(I18n.all({ zh: 'AI 助手', zhHant: 'AI 助手', ja: 'AI アシスタント', ko: 'AI 비서', en: 'AI Assistant', fr: 'Assistant IA', de: 'KI-Assistent', es: 'Asistente de IA' }))
          this.aiSection()

          this.sectionTitle(I18n.all({ zh: '备份', zhHant: '備份', ja: 'バックアップ', ko: '백업', en: 'Backup', fr: 'Sauvegarde', de: 'Sicherung', es: 'Copia de seguridad' }))
          this.backupSection()

          // 版本号（语言无关的纯文本，便于分辨安装包新旧；与 AppScope/app.json5 的 versionName 保持一致）
          Text('v1.0.1 alpha1')
            .fontSize(D.fontSizeCaption)
            .fontColor(this.tSecondary())
            .width('100%')
            .textAlign(TextAlign.Center)

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
      this.schemeChip('system', I18n.all({ zh: '跟随系统', zhHant: '跟隨系統', ja: 'システムに従う', ko: '시스템 따르기', en: 'Follow System', fr: 'Suivre le système', de: 'System folgen', es: 'Seguir el sistema' }))
      this.schemeChip('light', I18n.all({ zh: '亮色', zhHant: '亮色', ja: 'ライト', ko: '라이트', en: 'Light', fr: 'Clair', de: 'Hell', es: 'Claro' }))
      this.schemeChip('dark', I18n.all({ zh: '暗色', zhHant: '暗色', ja: 'ダーク', ko: '다크', en: 'Dark', fr: 'Sombre', de: 'Dunkel', es: 'Oscuro' }))
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
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      this.langChip('system', I18n.all({ zh: '跟随系统', zhHant: '跟隨系統', ja: 'システムに従う', ko: '시스템 따르기', en: 'Follow System', fr: 'Suivre le système', de: 'System folgen', es: 'Seguir el sistema' }))
      this.langChip('zh', '简体中文')
      this.langChip('zh-Hant', '繁體中文')
      this.langChip('ja', '日本語')
      this.langChip('ko', '한국어')
      this.langChip('en', 'English')
      this.langChip('fr', 'Français')
      this.langChip('de', 'Deutsch')
      this.langChip('es', 'Español')
    }.width('100%')
  }

  @Builder
  langChip(v: LanguageSetting, label: string) {
    Text(label)
      .fontSize(D.fontSizeBody2)
      .fontColor(this.m.language === v ? Color.White : this.tPrimary())
      .backgroundColor(this.m.language === v ? D.colorPrimary : this.colorPressed())
      .padding({ left: D.spaceLg, right: D.spaceLg, top: D.spaceSm, bottom: D.spaceSm })
      .margin({ right: D.spaceSm, bottom: D.spaceSm })
      .borderRadius(D.radiusPill)
      .onClick(() => this.applyLanguage(v))
  }

  @Builder
  aiSection() {
    Column({ space: D.spaceMd }) {
      this.fieldLabel(I18n.all({ zh: 'OpenAI 兼容 Base URL', zhHant: 'OpenAI 相容 Base URL', ja: 'OpenAI 互換 Base URL', ko: 'OpenAI 호환 Base URL', en: 'OpenAI compatible Base URL', fr: 'Base URL compatible OpenAI', de: 'OpenAI-kompatible Base-URL', es: 'Base URL compatible con OpenAI' }))
      TextInput({ text: this.m.baseUrl, placeholder: 'https://api.deepseek.com/v1' })
        .height(42)
        .borderRadius(D.radiusM)
        .backgroundColor(this.card())
        .fontColor(this.tPrimary())
        .onChange((v: string) => { this.m.baseUrl = v })
      this.fieldLabel(I18n.all({ zh: '模型名', zhHant: '模型名稱', ja: 'モデル名', ko: '모델명', en: 'Model name', fr: 'Nom du modèle', de: 'Modellname', es: 'Nombre del modelo' }))
      TextInput({ text: this.m.modelName, placeholder: 'deepseek-chat' })
        .height(42)
        .borderRadius(D.radiusM)
        .backgroundColor(this.card())
        .fontColor(this.tPrimary())
        .onChange((v: string) => { this.m.modelName = v })
      this.fieldLabel(I18n.all({ zh: 'API Key', zhHant: 'API Key', ja: 'API キー', ko: 'API 키', en: 'API Key', fr: 'Clé API', de: 'API-Schlüssel', es: 'Clave API' }))
      TextInput({ text: this.m.apiKey, placeholder: 'sk-...' })
        .type(InputType.Password)
        .height(42)
        .borderRadius(D.radiusM)
        .backgroundColor(this.card())
        .fontColor(this.tPrimary())
        .onChange((v: string) => { this.m.apiKey = v })
      Button(I18n.all({ zh: '保存 AI 配置', zhHant: '儲存 AI 設定', ja: 'AI 設定を保存', ko: 'AI 설정 저장', en: 'Save AI Config', fr: 'Enregistrer la config IA', de: 'KI-Konfiguration speichern', es: 'Guardar configuración de IA' }))
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
      Button(I18n.all({ zh: '导出备份到 Download', zhHant: '匯出備份到 Download', ja: 'バックアップを Download に書き出し', ko: '백업을 Download로 내보내기', en: 'Export backup to Download', fr: 'Exporter la sauvegarde vers Download', de: 'Sicherung nach Download exportieren', es: 'Exportar copia de seguridad a Download' }))
        .width('100%')
        .height(42)
        .borderRadius(D.radiusL)
        .backgroundColor(D.colorPrimary)
        .fontColor(Color.White)
        .onClick(() => this.exportBackup())
      Button(I18n.all({ zh: '导入备份', zhHant: '匯入備份', ja: 'バックアップを読み込み', ko: '백업 가져오기', en: 'Import backup', fr: 'Importer la sauvegarde', de: 'Sicherung importieren', es: 'Importar copia de seguridad' }))
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
      Text(I18n.all({ zh: '小艺助手', zhHant: '小藝助手', ja: '小芸アシスタント', ko: '샤오이 비서', en: 'Xiaoyi Assistant', fr: 'Assistant Xiaoyi', de: 'Xiaoyi-Assistent', es: 'Asistente Xiaoyi' }))
        .fontSize(D.fontSizeBody2)
        .fontColor(this.tPrimary())
        .width('100%')
      Text(I18n.all({ zh: '小艺（盘古）无公开第三方 API，需华为开发者资质与其移动服务授权后方可内嵌。当前通过上方 OpenAI 兼容 API 提供 AI 能力。',
        zhHant: '小藝（盤古）無公開第三方 API，需華為開發者資質與其移動服務授權後方可內嵌。目前透過上方的 OpenAI 相容 API 提供 AI 能力。',
        ja: '小芸（盤古）には公開サードパーティ API がなく、華為開発者資格とモバイルサービス認可が必要です。現在は上記の OpenAI 互換 API で AI 機能を提供しています。',
        ko: '샤오이(판구)는 공개 타사 API가 없어 화웨이 개발자 자격과 모바일 서비스 인증이 필요합니다. 현재 위의 OpenAI 호환 API로 AI 기능을 제공합니다.',
        en: 'Xiaoyi (Pangu) has no public third-party API and requires Huawei developer credentials to integrate. AI is currently provided through the OpenAI-compatible API above.',
        fr: 'Xiaoyi (Pangu) ne dispose d\u2019aucune API tierce publique et nécessite des accréditations de développement Huawei. L\u2019IA est actuellement fournie via l\u2019API compatible OpenAI ci-dessus.',
        de: 'Xiaoyi (Pangu) verf\u00fcgt \u00fcber keine \u00f6ffentliche Drittanbieter-API und erfordert Huawei-Entwicklerberechtigungen. Die KI wird derzeit \u00fcber die oben genannte OpenAI-kompatible API bereitgestellt.',
        es: 'Xiaoyi (Pangu) no posee una API de terceros p\u00fablica y requiere credenciales de desarrollador de Huawei. La IA se ofrece actualmente mediante la API compatible con OpenAI de arriba.' }))
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

  async applyLanguage(v: LanguageSetting): Promise<void> {
    this.m.language = v
    I18n.setLanguage(v)
    await this.saveSettings()
  }

  async saveSettings(): Promise<void> {
    await SettingsStore.save(this.m)
    promptAction.showToast({ message: I18n.all({ zh: '已保存', zhHant: '已儲存', ja: '保存しました', ko: '저장됨', en: 'Saved', fr: 'Enregistré', de: 'Gespeichert', es: 'Guardado' }) })
  }

  async exportBackup(): Promise<void> {
    if (this.exporting) {
      return
    }
    this.exporting = true
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      const path = await BackupService.export(ctx)
      promptAction.showToast({ message: I18n.all({ zh: '已导出', zhHant: '已匯出', ja: '書き出しました', ko: '내보냄', en: 'Exported', fr: 'Exporté', de: 'Exportiert', es: 'Exportado' }) + path })
    } catch (e) {
      promptAction.showToast({ message: I18n.all({ zh: '导出失败', zhHant: '匯出失敗', ja: '書き出しに失敗', ko: '내보내기 실패', en: 'Export failed', fr: 'Échec de l\u2019export', de: 'Export fehlgeschlagen', es: 'Error al exportar' }) })
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
        promptAction.showToast({ message: I18n.all({ zh: '无法读取文件', zhHant: '無法讀取檔案', ja: 'ファイルを読み取れません', ko: '파일을 읽을 수 없음', en: 'Cannot pick file', fr: 'Impossible de choisir le fichier', de: 'Datei kann nicht gewählt werden', es: 'No se puede elegir el archivo' }) })
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
      promptAction.showToast({ message: I18n.all({ zh: `已导入 ${count} 个目标`, zhHant: `已匯入 ${count} 個目標`, ja: `${count} 個の目標を読み込みました`, ko: `목표 ${count}개를 가져왔습니다`, en: `Imported ${count} goals`, fr: `${count} objectifs importés`, de: `${count} Ziele importiert`, es: `Se importaron ${count} objetivos` }) })
    } catch (e) {
      promptAction.showToast({ message: I18n.all({ zh: '导入失败', zhHant: '匯入失敗', ja: '読み込みに失敗', ko: '가져오기 실패', en: 'Import failed', fr: 'Échec de l\u2019import', de: 'Import fehlgeschlagen', es: 'Error al importar' }) })
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