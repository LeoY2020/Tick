import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import { ChatMessage, TaskNode, AIChatSession } from '../model/ChatModels';
import { TaskItem } from '../model/TaskItem';
import { SettingsModel } from '../model/Settings';
import { SettingsStore, ChatRepository, TaskRepository } from '../data/Repositories';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { I18n } from '../model/I18n';
import { AIService, AIServiceError } from '../services/AIService';
import { DocumentTextExtractor } from '../services/DocumentTextExtractor';
import { Theme, ThemePalette, DesignTokens } from '../theme/DesignTokens';

const D = DesignTokens;

/** AI 对话页：多轮聊天 + 可选附件解析 + 生成任务写入当前目标 */
@Entry
@Component
struct AIChat {
  build() {
    Column() {
      this.page()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  page() {
    Column() {
      // 顶部栏（玻璃卡片）
      Row({ space: D.spaceSm }) {
        Button() {
          Image($r('app.media.ic_back'))
            .width(20)
            .height(20)
            .fillColor(this.tPrimary())
        }
        .width(40)
        .height(40)
        .borderRadius(D.radiusPill)
        .backgroundColor(this.glass())
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
        .onClick(() => router.back())

        Text(I18n.t('ai.chatTitle'))
          .fontSize(D.fontSizeTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tPrimary())
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button() {
          Row({ space: 5 }) {
            Image($r('app.media.ic_clip'))
              .width(15)
              .height(15)
              .fillColor(Color.White)
            Text(I18n.t('ai.attach'))
              .fontSize(D.fontSizeCaption)
              .fontColor(Color.White)
          }
        }
        .height(36)
        .borderRadius(D.radiusPill)
        .padding({ left: 12, right: 12 })
        .linearGradient({
          angle: 135,
          colors: [[this.heroAC(), 0], [this.heroBC(), 1]]
        })
        .shadow({ radius: 12, color: this.glowAC(), offsetY: 5 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
        .onClick(() => this.attach())
      }
      .width('100%')
      .padding({ left: D.spaceXs, right: D.spaceXs, top: D.spaceXs, bottom: D.spaceXs })
      .margin({ left: D.spaceMd, right: D.spaceMd, top: D.spaceSm })
      .backgroundColor(this.glass())
      .borderRadius(D.radiusXl)
      .border({ width: 1, color: this.borderC() })
      .shadow({ radius: 20, color: this.shadowC(), offsetY: 8 })

      // 显示选中的附件名
      if (this.attachmentName.length > 0) {
        Row({ space: 6 }) {
          Image($r('app.media.ic_clip'))
            .width(13)
            .height(13)
            .fillColor(this.heroAC())
          Text(this.attachmentName)
            .fontSize(D.fontSizeCaption)
            .fontColor(this.tSecondary())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .margin({ left: D.spaceMd, right: D.spaceMd, top: D.spaceSm })
        .borderRadius(D.radiusPill)
        .backgroundColor(this.accentSoft())
      }

      // 消息列表
      List({ space: D.spaceMd }) {
        ForEach(this.messages, (msg: ChatMessage) => {
          ListItem() {
            this.messageBubble(msg)
          }
          .transition(TransitionEffect.OPACITY
            .animation({ duration: D.animNormal, curve: Curve.EaseOut })
            .combine(TransitionEffect.translate({ y: 10 })))
        }, (msg: ChatMessage) => msg.id)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: D.spaceMd, right: D.spaceMd, top: D.spaceMd })
      .scrollBar(BarState.Off)

      // 输入区（浮起玻璃面板）
      Row({ space: D.spaceSm }) {
        TextInput({ placeholder: I18n.t('ai.input'), text: this.inputText })
          .layoutWeight(1)
          .height(44)
          .borderRadius(D.radiusPill)
          .backgroundColor(this.track())
          .fontColor(this.tPrimary())
          .onChange((v: string) => { this.inputText = v })
          .onSubmit(() => this.send())
        Button() {
          Image($r('app.media.ic_send'))
            .width(19)
            .height(19)
            .fillColor(Color.White)
        }
        .width(44)
        .height(44)
        .borderRadius(D.radiusPill)
        .linearGradient({
          angle: 135,
          colors: [[this.heroAC(), 0], [this.heroBC(), 1]]
        })
        .shadow({ radius: 14, color: this.glowAC(), offsetY: 5 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => this.send())
      }
      .width('100%')
      .padding(D.spaceXs)
      .margin({ left: D.spaceMd, right: D.spaceMd, top: D.spaceSm, bottom: D.spaceSm })
      .backgroundColor(this.glass())
      .borderRadius(D.radiusXl)
      .border({ width: 1, color: this.borderC() })
      .shadow({ radius: 20, color: this.shadowC(), offsetY: 8 })

      if (this.busy) {
        Row({ space: 6 }) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(this.heroAC())
          Text(I18n.t('ai.sending'))
            .fontSize(D.fontSizeCaption)
            .fontColor(this.tSecondary())
        }
        .padding({ bottom: D.spaceSm })
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [[this.bgTop(), 0], [this.bg(), 0.55], [this.bgBottom(), 1]]
    })
  }

  @Builder
  messageBubble(msg: ChatMessage) {
    Row({ space: 8 }) {
      if (msg.role === 'assistant') {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(26)
            .height(26)
            .linearGradient({
              angle: 135,
              colors: [[this.heroAC(), 0], [this.heroBC(), 1]]
            })
          Image($r('app.media.ic_ai'))
            .width(14)
            .height(14)
            .fillColor(Color.White)
        }
        .margin({ top: D.spaceXs })
      } else {
        Blank()
      }

      if (msg.role === 'user') {
        Column() {
          Text(msg.text)
            .fontSize(D.fontSizeBody)
            .fontColor(Color.White)
            .lineHeight(22)
        }
        .constraintSize({ maxWidth: '78%' })
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .borderRadius({ topLeft: D.radiusL, topRight: D.radiusL, bottomLeft: D.radiusL, bottomRight: 6 })
        .linearGradient({
          angle: 135,
          colors: [[this.heroAC(), 0], [this.heroBC(), 1]]
        })
        .shadow({ radius: 14, color: this.glowAC(), offsetY: 4 })
      } else {
        Column() {
          Text(msg.text)
            .fontSize(D.fontSizeBody)
            .fontColor(this.tPrimary())
            .lineHeight(22)
        }
        .constraintSize({ maxWidth: '78%' })
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .borderRadius({ topLeft: D.radiusL, topRight: D.radiusL, bottomLeft: 6, bottomRight: D.radiusL })
        .backgroundColor(this.card())
        .border({ width: 1, color: this.borderC() })
        .shadow({ radius: 12, color: this.shadowC(), offsetY: 3 })
      }

      if (msg.role === 'assistant') {
        Blank()
      }
    }
    .width('100%')
  }

  // ===== 状态 =====
  @State messages: ChatMessage[] = []
  @State inputText: string = ''
  @State attachmentName: string = ''
  @State busy: boolean = false
  @State settings: SettingsModel = new SettingsModel()
  @State colorScheme: 'system' | 'light' | 'dark' = 'system'

  private attachmentText: string | undefined = undefined
  private goalId: string = ''
  private session: AIChatSession | undefined = undefined

  aboutToAppear(): void {
    this.load()
  }

  async load(): Promise<void> {
    this.settings = await SettingsStore.load()
    I18n.setLanguage(this.settings.language)
    this.colorScheme = this.settings.colorScheme

    // 读取跳转参数中的目标
    const params = router.getParams() as Record<string, string>
    this.goalId = params !== undefined && params !== null && params['goalId'] !== undefined ? params['goalId'] : ''
    if (this.goalId.length === 0) {
      const goals = await AppViewModel.loadGoals()
      if (goals.length > 0) {
        this.goalId = goals[0].id
      }
    }

    // 恢复上次会话
    const sessions = await ChatRepository.list()
    if (sessions.length > 0) {
      this.session = sessions[0]
      const parsed = this.parseMessages(sessions[0].messagesData)
      this.messages = parsed
      this.attachmentText = sessions[0].attachmentText
      this.attachmentName = sessions[0].attachmentName === undefined ? '' : (sessions[0].attachmentName as string)
    }
  }

  private parseMessages(data: string): ChatMessage[] {
    if (data === undefined || data === null || data.length === 0) {
      return []
    }
    try {
      return JSON.parse(data) as ChatMessage[]
    } catch (e) {
      return []
    }
  }

  async attach(): Promise<void> {
    const hostCtx = this.getUIContext().getHostContext()
    if (hostCtx === undefined) {
      return
    }
    const documentPicker = new picker.DocumentViewPicker(hostCtx as common.Context)
    const result = await documentPicker.select({ maxSelectNumber: 1 })
    const uriList: string[] = result
    const uri = (uriList !== undefined && uriList.length > 0) ? uriList[0] : ''
    if (uri === undefined || uri.length === 0) {
      return
    }
    try {
      const text = await DocumentTextExtractor.extractText(uri)
      this.attachmentText = text
      this.attachmentName = this.fileNameOf(uri)
    } catch (e) {
      const err = e as Error
      const msg = err !== undefined && err.message !== undefined ? err.message : I18n.t('ai.attachParseFailed')
      promptAction.showToast({ message: msg })
      // 友好提示:PDF 等格式解析失败
    }
  }

  private fileNameOf(uri: string): string {
    const idx = uri.lastIndexOf('/')
    return idx >= 0 ? uri.substring(idx + 1) : uri
  }

  async send(): Promise<void> {
    const text = this.inputText.trim()
    if (text.length === 0) {
      return
    }
    if (this.busy) {
      return
    }
    this.inputText = ''
    const userMsg: ChatMessage = this.makeMessage('user', text)
    this.messages.push(userMsg)
    this.busy = true
    try {
      const reply = await AIService.chatReply(this.history(), this.attachmentText, this.settings)
      // 生成任务：写入当前目标（不展示），仅展示 message
      if (reply.shouldGenerateTasks) {
        const cleanTasks = this.filterEmpty(reply.tasks)
        if (cleanTasks.length > 0) {
          await this.writeTasks(cleanTasks)
        }
      }
      const replyText = reply.message.length > 0 ? reply.message : this.defaultReplyText()
      const assistantMsg: ChatMessage = this.makeMessage('assistant', replyText)
      this.messages.push(assistantMsg)
      await this.persist()
    } catch (e) {
      const err = e as AIServiceError
      const msg = err !== undefined && err.message !== undefined ? err.message : I18n.t('ai.requestFailed')
      const errMsg: ChatMessage = this.makeMessage('assistant', msg)
      this.messages.push(errMsg)
      await this.persist()
    } finally {
      this.busy = false
    }
  }

  private history(): ChatMessage[] {
    const out: ChatMessage[] = []
    for (const m of this.messages) {
      out.push(m)
    }
    return out
  }

  private makeMessage(role: 'user' | 'assistant', text: string): ChatMessage {
    return {
      id: this.randomId(),
      role: role,
      text: text,
      createdAt: Date.now()
    }
  }

  private randomId(): string {
    return 'm_' + Date.now().toString() + '_' + Math.floor(Math.random() * 100000).toString()
  }

  private defaultReplyText(): string {
    return I18n.t('ai.done')
  }

  private filterEmpty(nodes: TaskNode[]): TaskNode[] {
    const out: TaskNode[] = []
    for (const n of nodes) {
      if (n !== undefined && n.name !== undefined && n.name.trim().length > 0) {
        out.push(n)
      }
    }
    return out
  }

  private async writeTasks(nodes: TaskNode[]): Promise<void> {
    if (this.goalId.length === 0) {
      return
    }
    const tasks = this.nodesToTasks(nodes)
    await TaskRepository.insertTree(tasks, this.goalId, undefined)
  }

  private nodesToTasks(nodes: TaskNode[]): TaskItem[] {
    const out: TaskItem[] = []
    for (const n of nodes) {
      const t = new TaskItem(n.name === undefined ? '' : n.name)
      const children = n.children === undefined ? [] : n.children
      t.subtasks = this.nodesToTasks(children)
      out.push(t)
    }
    return out
  }

  private async persist(): Promise<void> {
    if (this.session === undefined) {
      this.session = new AIChatSession(I18n.t('ai.chatTitle'))
    }
    this.session.messagesData = JSON.stringify(this.messages)
    this.session.messageCount = this.messages.length
    this.session.attachmentText = this.attachmentText
    this.session.attachmentName = this.attachmentName.length > 0 ? this.attachmentName : undefined
    this.session.updatedAt = Date.now()
    await ChatRepository.save(this.session)
  }

  // ===== 主题辅助 =====
  private isDark(): boolean {
    return Theme.dark(this.colorScheme)
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

  private bgTop(): string {
    return this.pal().bgTop
  }

  private bgBottom(): string {
    return this.pal().bgBottom
  }

  private heroAC(): string {
    return this.pal().heroA
  }

  private heroBC(): string {
    return this.pal().heroB
  }

  private glowAC(): string {
    return this.pal().glowA
  }

  private glass(): string {
    return this.isDark() ? '#E8171A24' : '#EFFFFFFF'
  }

  private borderC(): string {
    return this.pal().border
  }

  private track(): string {
    return this.pal().track
  }

  private shadowC(): string {
    return this.pal().shadow
  }

  private accentSoft(): string {
    return this.pal().accentSoft
  }
}