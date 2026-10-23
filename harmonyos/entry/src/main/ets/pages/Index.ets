import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Goal } from '../model/Goal';
import { TaskItem } from '../model/TaskItem';
import { SettingsModel } from '../model/Settings';
import { SettingsStore } from '../data/Repositories';
import { AppViewModel, TaskRow, GoalProgressView } from '../viewmodel/AppViewModel';
import { I18n } from '../model/I18n';
import { CountdownFormatter } from '../services/CountdownFormatter';
import { ReminderService } from '../services/ReminderService';
import { TaskType, TaskStatus, RepeatRule } from '../model/Enums';
import { DesignTokens, COLOR_PALETTE, PaletteColor, Theme, ThemePalette } from '../theme/DesignTokens';

const D = DesignTokens;

/** 任务编辑面板状态 */
class TaskEditBuffer {
  mode: 'new' | 'newChild' | 'edit' = 'new';
  id: string = '';
  goalId: string = '';
  parentId: string | undefined = undefined;
  name: string = '';
  type: TaskType = 'single';
  status: TaskStatus = 'notDone';
  totalAmount: number = 0;
  currentAmount: number = 0;
  colorHex: string | undefined = undefined;
  hasReminder: boolean = false;
  reminderMs: number = Date.now();
  repeatRule: RepeatRule = 'never';
  weekdays: number[] = [];
}

/** 目标编辑面板状态 */
class GoalEditBuffer {
  isNew: boolean = true;
  id: string = '';
  name: string = '';
  colorHex: string = 'auto';
  countingMode: 'allTasks' | 'leafTasks' = 'allTasks';
}

@Entry
@Component
struct Index {
  build() {
    Column() {
      this.page()
    }
    .width('100%')
    .height('100%')
  }

  // ===== 页面根 =====
  @Builder
  page() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.headerBar()
        if (this.selectedGoalId.length === 0) {
          this.emptyState()
        } else {
          this.goalHeader()
          this.goalProgressArea()
          Column() {
            List({ space: D.spaceSm }) {
              ForEach(this.buildRows(), (row: TaskRow) => {
                ListItem() {
                  this.taskRow(row)
                }
                .bindContextMenu(this.rowMenu(row), ResponseType.LongPress)
              }, (row: TaskRow) => row.task.id)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ bottom: D.spaceLg })
          }
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')

      // 主操作按钮：品牌色实心圆（无渐变、无辉光）
      if (this.selectedGoalId.length > 0) {
        Button() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(24)
            .fontColor([$r('sys.color.font_on_primary')])
        }
        .width(56)
        .height(56)
        .borderRadius(D.radiusPill)
        .backgroundColor($r('sys.color.brand'))
        .margin({ bottom: 28, right: 20 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
        .onClick(() => this.openAddTopTask())
      }

      // 目标抽屉侧边栏
      if (this.sidebarShown) {
        this.sidebar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .bindSheet($$this.taskSheetVisible, this.taskSheetBuilder(), {
      height: 560,
      showClose: true,
      dragBar: true
    })
    .bindSheet($$this.goalSheetVisible, this.goalSheetBuilder(), {
      height: 520,
      showClose: true,
      dragBar: true
    })
  }

  // ===== 顶部导航栏 =====
  @Builder
  headerBar() {
    Row({ space: D.spaceXs }) {
      Button() {
        SymbolGlyph($r('sys.symbol.open_sidebar'))
          .fontSize(22)
          .fontColor([this.tPrimary()])
      }
      .width(44)
      .height(44)
      .borderRadius(D.radiusPill)
      .backgroundColor(Color.Transparent)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .onClick(() => {
        this.sidebarShown = true
      })

      Text(this.selectedGoalName.length > 0 ? this.selectedGoalName : 'Tick')
        .fontSize(D.fontSizeTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tPrimary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Button() {
        SymbolGlyph($r('sys.symbol.wand_and_stars'))
          .fontSize(22)
          .fontColor([this.tPrimary()])
      }
      .width(44)
      .height(44)
      .borderRadius(D.radiusPill)
      .backgroundColor(Color.Transparent)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/AIChat', params: { goalId: this.selectedGoalId } })
      })
      Button() {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(22)
          .fontColor([this.tPrimary()])
      }
      .width(44)
      .height(44)
      .borderRadius(D.radiusPill)
      .backgroundColor(Color.Transparent)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/Settings' })
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: D.spaceSm, right: D.spaceSm })
  }

  // ===== 空态 =====
  @Builder
  emptyState() {
    Column({ space: D.spaceLg }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(96)
          .height(96)
          .fill($r('sys.color.comp_background_tertiary'))
        SymbolGlyph($r('sys.symbol.scope'))
          .fontSize(44)
          .fontColor([this.tTertiary()])
      }
      Text(I18n.t('goals.empty'))
        .fontSize(D.fontSizeBody)
        .fontColor(this.tSecondary())
      Button() {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_on_primary')])
          Text(I18n.t('goals.add'))
            .fontSize(D.fontSizeBody2)
            .fontColor($r('sys.color.font_on_primary'))
        }
      }
      .height(40)
      .padding({ left: D.spaceXl, right: D.spaceXl })
      .borderRadius(D.radiusPill)
      .backgroundColor($r('sys.color.brand'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
      .onClick(() => this.openAddGoal())
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ===== 目标标题 + 倒计时 =====
  @Builder
  goalHeader() {
    Row({ space: D.spaceSm }) {
      // 目标徽标（品牌色实心，内嵌系统符号）
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(44)
          .height(44)
          .fill($r('sys.color.brand'))
        SymbolGlyph($r('sys.symbol.scope'))
          .fontSize(22)
          .fontColor([$r('sys.color.font_on_primary')])
      }

      Column({ space: 2 }) {
        Text(this.selectedGoalName)
          .fontSize(D.fontSizeTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tPrimary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(I18n.t('tasks.remaining'))
          .fontSize(D.fontSizeCaption)
          .fontColor(this.tSecondary())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.selectedEndDate !== undefined) {
        Column({ space: 2 }) {
          if (CountdownFormatter.countdown(this.selectedEndDate, this.selectedEndPrecise) !== undefined) {
            Text(CountdownFormatter.countdown(this.selectedEndDate, this.selectedEndPrecise) as string)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tPrimary())
          }
          Text(CountdownFormatter.endDateLabel(this.selectedEndDate, this.selectedEndPrecise))
            .fontSize(10)
            .fontColor(this.tTertiary())
        }
        .alignItems(HorizontalAlign.End)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .borderRadius(D.radiusM)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
      }
    }
    .width('100%')
    .padding(D.spaceMd)
    .margin({ left: D.spaceMd, right: D.spaceMd, top: D.spaceSm })
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .borderRadius(D.radiusXl)
    .transition(TransitionEffect.OPACITY
      .animation({ duration: D.animNormal, curve: Curve.EaseInOut })
      .combine(TransitionEffect.translate({ y: 8 })))
  }

  // ===== 目标总进度 =====
  @Builder
  goalProgressArea() {
    Column({ space: D.spaceXs }) {
      Progress({ value: this.goalFraction() * 100, total: 100, type: ProgressType.Linear })
        .color($r('sys.color.brand'))
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .height(8)
        .borderRadius(4)
        .width('100%')
        .animation({ duration: D.animNormal, curve: Curve.EaseInOut })

      Row() {
        Text(I18n.t('tasks.completed', Math.round(this.goalCompletedWeight()).toString(), this.goalTotalItems().toString()))
          .fontSize(D.fontSizeCaption)
          .fontColor(this.tSecondary())
        Blank()
        Text(`${(this.goalFraction() * 100).toFixed(1)}%`)
          .fontSize(D.fontSizeBody2)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tPrimary())
      }.width('100%')
    }
    .width('100%')
    .padding(D.spaceMd)
    .margin({ left: D.spaceMd, right: D.spaceMd, top: D.spaceSm })
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .borderRadius(D.radiusXl)
  }

  // ===== 单个任务行 =====
  @Builder
  taskRow(row: TaskRow) {
    Row({ space: D.spaceSm }) {
      // 展开箭头（系统符号，随展开状态平滑旋转）
      if (row.hasChildren) {
        SymbolGlyph(row.expanded ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([this.tSecondary()])
          .animation({ duration: D.animFast, curve: Curve.EaseInOut })
          .onClick(() => this.toggleExpand(row.task.id))
      } else {
        Blank().width(16)
      }
      // 颜色圆点
      Circle()
        .width(8)
        .height(8)
        .fill(this.resolveColor(AppViewModel.effectiveColor(row.task)))
      // 名称
      Text(row.task.name)
        .fontSize(D.fontSizeBody)
        .fontColor(this.isDeletedTask(row.task) ? this.tTertiary() : this.tPrimary())
        .opacity(this.isDeletedTask(row.task) ? 0.5 : 1)
        .decoration({ type: this.isDeletedTask(row.task) ? TextDecorationType.LineThrough : TextDecorationType.None })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      // 右侧状态 / 进度控件
      this.trailingControl(row)
    }
    .width('100%')
    .padding({ left: Math.min(row.depth * 16, 80), right: D.spaceMd, top: 12, bottom: 12 })
    .margin({ left: D.spaceMd, right: D.spaceMd, top: 4 })
    .borderRadius(D.radiusL)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .transition(TransitionEffect.OPACITY
      .animation({ duration: D.animNormal, curve: Curve.EaseInOut })
      .combine(TransitionEffect.translate({ y: 6 })))
  }

  // ===== 行尾控件 =====
  @Builder
  trailingControl(row: TaskRow) {
    if (row.task.type === 'single') {
      this.singleControl(row)
    } else {
      this.progressControl(row)
    }
  }

  // ===== 单项状态控件 =====
  @Builder
  singleControl(row: TaskRow) {
    Row() {
      SymbolGlyph(this.statusSymbol(AppViewModel.effectiveStatus(row.task)))
        .fontSize(24)
        .fontColor([this.statusColor(AppViewModel.effectiveStatus(row.task))])
        .animation({ duration: D.animNormal, curve: Curve.EaseInOut })
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .onClick(() => {
      if (!row.hasChildren) {
        this.cycleStatus(row.task)
      }
    })
  }

  // ===== 进度控件 =====
  @Builder
  progressControl(row: TaskRow) {
    Row({ space: 6 }) {
      if (!row.hasChildren) {
        Button() {
          SymbolGlyph($r('sys.symbol.minus'))
            .fontSize(14)
            .fontColor([this.tSecondary()])
        }
        .width(28)
        .height(28)
        .borderRadius(D.radiusS)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => this.adjustProgress(row.task, -1))
      }
      Text(this.taskProgressLabel(row.task))
        .fontSize(D.fontSizeCaption)
        .fontColor(this.tSecondary())
      Progress({ value: this.taskProgressPercent(row.task), total: 100, type: ProgressType.Linear })
        .width(52)
        .height(4)
        .borderRadius(2)
        .color($r('sys.color.brand'))
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .animation({ duration: D.animNormal, curve: Curve.EaseInOut })
      if (!row.hasChildren) {
        Button() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(14)
            .fontColor([this.tSecondary()])
        }
        .width(28)
        .height(28)
        .borderRadius(D.radiusS)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => this.adjustProgress(row.task, 1))
      }
    }
  }

  // ===== 行右键菜单 =====
  @Builder
  rowMenu(row: TaskRow) {
    Menu() {
      MenuItem({ content: I18n.t('tasks.edit') })
        .onClick(() => this.openEditTask(row.task))
      MenuItem({ content: I18n.t('tasks.addSubtask') })
        .onClick(() => this.openAddChild(row.task))
      MenuItem({ content: I18n.t('common.delete') })
        .onClick(() => this.confirmDelete(row.task))
    }
  }

  // ===== 目标抽屉侧边栏 =====
  @Builder
  sidebar() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 遮罩
      Column().width('100%').height('100%').backgroundColor('#40000000').onClick(() => { this.sidebarShown = false })
      // 面板
      Column() {
        Text(I18n.t('nav.goals'))
          .fontSize(D.fontSizeTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tPrimary())
          .width('100%')
          .margin({ bottom: D.spaceMd })
        List({ space: D.spaceSm }) {
          ForEach(this.goals, (g: Goal) => {
            ListItem() {
              Row() {
                Circle()
                  .width(8)
                  .height(8)
                  .fill(this.resolveColor(g.colorHex))
                Text(g.name)
                  .fontSize(D.fontSizeBody)
                  .fontColor(this.tPrimary())
                  .fontWeight(this.selectedGoalId === g.id ? FontWeight.Medium : FontWeight.Normal)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                if (this.selectedGoalId === g.id) {
                  SymbolGlyph($r('sys.symbol.checkmark'))
                    .fontSize(16)
                    .fontColor([$r('sys.color.brand')])
                }
              }
              .width('100%')
              .padding(D.spaceSm)
              .borderRadius(D.radiusM)
              .backgroundColor(this.selectedGoalId === g.id ? $r('sys.color.comp_background_tertiary') : Color.Transparent)
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
              .onClick(() => {
                this.selectGoal(g.id)
                this.sidebarShown = false
              })
            }
            .swipeAction({ end: this.deleteGoalSwipe(g) })
          }, (g: Goal) => g.id)
        }
        .layoutWeight(1)
        .width('100%')

        Button() {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(16)
              .fontColor([$r('sys.color.font_on_primary')])
            Text(I18n.t('goals.new'))
              .fontSize(D.fontSizeBody2)
              .fontColor($r('sys.color.font_on_primary'))
          }
        }
        .width('100%')
        .height(40)
        .borderRadius(D.radiusM)
        .backgroundColor($r('sys.color.brand'))
        .margin({ top: D.spaceMd })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
        .onClick(() => {
          this.sidebarShown = false
          this.openAddGoal()
        })
        Button(I18n.t('nav.settings'))
          .width('100%')
          .height(40)
          .borderRadius(D.radiusM)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .fontColor(this.tPrimary())
          .margin({ top: D.spaceSm })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
          .onClick(() => {
            this.sidebarShown = false
            router.pushUrl({ url: 'pages/Settings' })
          })
      }
      .width(280)
      .height('100%')
      .padding(D.spaceLg)
      .backgroundColor($r('sys.color.background_primary'))
      .borderRadius({ topRight: D.radiusXl, bottomRight: D.radiusXl })
      .shadow({ radius: 24, color: '#33000000', offsetX: 6 })
      .transition(TransitionEffect.OPACITY
        .animation({ duration: D.animNormal, curve: Curve.EaseInOut })
        .combine(TransitionEffect.translate({ x: -32 })))
    }
  }

  @Builder
  deleteGoalSwipe(g: Goal) {
    Menu() {
      MenuItem({ content: I18n.t('goals.delete') })
        .onClick(() => this.confirmDeleteGoal(g))
      MenuItem({ content: I18n.t('goals.edit') })
        .onClick(() => this.openEditGoal(g))
    }
  }

  // ===== 任务编辑面板 =====
  @Builder
  taskSheetBuilder() {
    Column({ space: D.spaceMd }) {
      TextInput({ placeholder: I18n.t('task.namePlaceholder'), text: this.taskBuf.name })
        .height(44)
        .borderRadius(D.radiusM)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onChange((v: string) => { this.taskBuf.name = v })

      // 类型选择
      Row({ space: D.spaceSm }) {
        this.typeChip('single', I18n.t('task.single'))
        this.typeChip('progress', I18n.t('task.progress'))
      }.width('100%')

      if (this.taskBuf.type === 'progress') {
        Row({ space: D.spaceMd }) {
          Column({ space: 4 }) {
            Text(I18n.t('task.total')).fontSize(D.fontSizeCaption).fontColor(this.tSecondary())
            TextInput({ text: this.taskBuf.totalAmount.toString() })
              .type(InputType.Number)
              .height(40)
              .borderRadius(D.radiusM)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .onChange((v: string) => {
                this.taskBuf.totalAmount = Number.parseFloat(v)
                if (Number.isNaN(this.taskBuf.totalAmount)) { this.taskBuf.totalAmount = 0 }
              })
          }.layoutWeight(1)
          Column({ space: 4 }) {
            Text(I18n.t('task.current')).fontSize(D.fontSizeCaption).fontColor(this.tSecondary())
            TextInput({ text: this.taskBuf.currentAmount.toString() })
              .type(InputType.Number)
              .height(40)
              .borderRadius(D.radiusM)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .onChange((v: string) => {
                this.taskBuf.currentAmount = Number.parseFloat(v)
                if (Number.isNaN(this.taskBuf.currentAmount)) { this.taskBuf.currentAmount = 0 }
              })
          }.layoutWeight(1)
        }.width('100%')
      } else {
        Row({ space: D.spaceSm }) {
          Text(I18n.t('task.status')).fontSize(D.fontSizeBody2).fontColor(this.tSecondary())
          this.statusChip('notDone', I18n.t('task.notDone'))
          this.statusChip('done', I18n.t('task.done'))
          this.statusChip('deleted', I18n.t('task.deleted'))
        }.width('100%')
      }

      // 颜色
      Scroll() {
        Row({ space: D.spaceSm }) {
          ForEach(COLOR_PALETTE, (c: PaletteColor) => {
            Column() {
              Circle()
                .width(28)
                .height(28)
                .fill(c.hex)
              if (this.taskBuf.colorHex === c.hex) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(14)
                  .fontColor([Color.White])
                  .position({ x: 9, y: 9 })
              }
            }
            .width(32)
            .height(32)
            .onClick(() => { this.taskBuf.colorHex = c.hex })
          }, (c: PaletteColor) => c.hex)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .height(36)

      // 提醒
      Column({ space: D.spaceSm }) {
        Row() {
          Text(I18n.t('task.reminder')).fontSize(D.fontSizeBody2).fontColor(this.tSecondary())
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.taskBuf.hasReminder })
            .onChange((on: boolean) => { this.taskBuf.hasReminder = on })
        }.width('100%')
        if (this.taskBuf.hasReminder) {
          // 重复规则
          Row({ space: D.spaceSm }) {
            this.repeatChip('never', I18n.t('repeat.never'))
            this.repeatChip('daily', I18n.t('repeat.daily'))
            this.repeatChip('weekly', I18n.t('repeat.weekly'))
            this.repeatChip('monthly', I18n.t('repeat.monthly'))
            this.repeatChip('custom', I18n.t('repeat.custom'))
          }.width('100%')
          if (this.taskBuf.repeatRule === 'custom') {
            Row({ space: D.spaceSm }) {
              ForEach([1, 2, 3, 4, 5, 6, 7], (w: number) => {
                Text(I18n.t('weekday.' + w.toString()))
                  .fontSize(D.fontSizeCaption)
                  .fontColor(this.taskBuf.weekdays.indexOf(w) >= 0 ? $r('sys.color.font_on_primary') : this.tPrimary())
                  .backgroundColor(this.taskBuf.weekdays.indexOf(w) >= 0 ? $r('sys.color.brand') : $r('sys.color.comp_background_tertiary'))
                  .width(34)
                  .height(34)
                  .borderRadius(D.radiusPill)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.toggleWeekday(w))
              }, (w: number) => w.toString())
            }.width('100%').justifyContent(FlexAlign.SpaceBetween)
          }
        }
      }.width('100%')

      Button(I18n.t('common.save'))
        .width('100%')
        .height(44)
        .borderRadius(D.radiusM)
        .backgroundColor($r('sys.color.brand'))
        .fontColor($r('sys.color.font_on_primary'))
        .margin({ top: D.spaceSm })
        .onClick(() => this.saveTaskEditor())
    }
    .padding(D.spaceLg)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  typeChip(t: TaskType, label: string) {
    Text(label)
      .fontSize(D.fontSizeBody2)
      .fontColor(this.taskBuf.type === t ? $r('sys.color.font_on_primary') : this.tPrimary())
      .backgroundColor(this.taskBuf.type === t ? $r('sys.color.brand') : $r('sys.color.comp_background_tertiary'))
      .padding({ left: D.spaceLg, right: D.spaceLg, top: D.spaceSm, bottom: D.spaceSm })
      .borderRadius(D.radiusPill)
      .onClick(() => { this.taskBuf.type = t })
  }

  @Builder
  statusChip(s: TaskStatus, label: string) {
    Text(label)
      .fontSize(D.fontSizeCaption)
      .fontColor(this.taskBuf.status === s ? $r('sys.color.font_on_primary') : this.tPrimary())
      .backgroundColor(this.taskBuf.status === s ? $r('sys.color.brand') : $r('sys.color.comp_background_tertiary'))
      .padding({ left: D.spaceMd, right: D.spaceMd, top: 4, bottom: 4 })
      .borderRadius(D.radiusPill)
      .onClick(() => { this.taskBuf.status = s })
  }

  @Builder
  repeatChip(r: RepeatRule, label: string) {
    Text(label)
      .fontSize(D.fontSizeCaption)
      .fontColor(this.taskBuf.repeatRule === r ? $r('sys.color.font_on_primary') : this.tPrimary())
      .backgroundColor(this.taskBuf.repeatRule === r ? $r('sys.color.brand') : $r('sys.color.comp_background_tertiary'))
      .padding({ left: D.spaceMd, right: D.spaceMd, top: 4, bottom: 4 })
      .borderRadius(D.radiusPill)
      .onClick(() => { this.taskBuf.repeatRule = r })
  }

  toggleWeekday(w: number): void {
    const idx = this.taskBuf.weekdays.indexOf(w)
    if (idx >= 0) {
      this.taskBuf.weekdays.splice(idx, 1)
    } else {
      this.taskBuf.weekdays.push(w)
    }
    this.revision++
  }

  // ===== 目标编辑面板 =====
  @Builder
  goalSheetBuilder() {
    Column({ space: D.spaceMd }) {
      TextInput({ placeholder: I18n.t('goals.namePlaceholder'), text: this.goalBuf.name })
        .height(44)
        .borderRadius(D.radiusM)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onChange((v: string) => { this.goalBuf.name = v })

      // 颜色
      Column({ space: D.spaceSm }) {
        Text(I18n.t('task.color')).fontSize(D.fontSizeBody2).fontColor(this.tSecondary()).width('100%')
        Scroll() {
          Row({ space: D.spaceSm }) {
            ForEach(COLOR_PALETTE, (c: PaletteColor) => {
              Column() {
                Circle()
                  .width(28)
                  .height(28)
                  .fill(c.hex)
                if (this.goalBuf.colorHex === c.hex) {
                  SymbolGlyph($r('sys.symbol.checkmark'))
                    .fontSize(14)
                    .fontColor([Color.White])
                    .position({ x: 9, y: 9 })
                }
              }
              .width(32)
              .height(32)
              .onClick(() => { this.goalBuf.colorHex = c.hex })
            }, (c: PaletteColor) => c.hex)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
        .height(36)
      }.width('100%')

      Column({ space: 4 }) {
        Text(I18n.t('goals.countingMode')).fontSize(D.fontSizeBody2).fontColor(this.tSecondary()).width('100%')
        Row({ space: D.spaceSm }) {
          Text(I18n.t('goals.countAllTasks'))
            .fontSize(D.fontSizeCaption)
            .fontColor(this.goalBuf.countingMode === 'allTasks' ? $r('sys.color.font_on_primary') : this.tPrimary())
            .backgroundColor(this.goalBuf.countingMode === 'allTasks' ? $r('sys.color.brand') : $r('sys.color.comp_background_tertiary'))
            .padding({ left: D.spaceMd, right: D.spaceMd, top: 6, bottom: 6 })
            .borderRadius(D.radiusPill)
            .onClick(() => { this.goalBuf.countingMode = 'allTasks' })
          Text(I18n.t('goals.countLeafTasks'))
            .fontSize(D.fontSizeCaption)
            .fontColor(this.goalBuf.countingMode === 'leafTasks' ? $r('sys.color.font_on_primary') : this.tPrimary())
            .backgroundColor(this.goalBuf.countingMode === 'leafTasks' ? $r('sys.color.brand') : $r('sys.color.comp_background_tertiary'))
            .padding({ left: D.spaceMd, right: D.spaceMd, top: 6, bottom: 6 })
            .borderRadius(D.radiusPill)
            .onClick(() => { this.goalBuf.countingMode = 'leafTasks' })
        }.width('100%')
      }.width('100%')

      Button(I18n.t('common.save'))
        .width('100%')
        .height(44)
        .borderRadius(D.radiusM)
        .backgroundColor($r('sys.color.brand'))
        .fontColor($r('sys.color.font_on_primary'))
        .onClick(() => this.saveGoalEditor())
    }
    .padding(D.spaceLg)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  // ===== 状态字段（非响应式，供 buildRows/渲染使用）=====
  private goals: Goal[] = []
  private currentTree: TaskItem[] = []
  private expanded: Set<string> = new Set<string>()
  private selectedGoalName: string = ''
  private selectedGoalColor: string = 'auto'
  private selectedEndDate: number | undefined = undefined
  private selectedEndPrecise: boolean = false
  private selectedCountingMode: 'allTasks' | 'leafTasks' = 'allTasks'
  private taskBuf: TaskEditBuffer = new TaskEditBuffer()
  private goalBuf: GoalEditBuffer = new GoalEditBuffer()
  private timer: number = 0

  // ===== 响应式字段 =====
  @State revision: number = 0
  @State selectedGoalId: string = ''
  @State sidebarShown: boolean = false
  @State taskSheetVisible: boolean = false
  @State goalSheetVisible: boolean = false
  @State colorScheme: 'system' | 'light' | 'dark' = 'system'

  aboutToAppear(): void {
    this.refreshGoals()
    this.loadSettings()
    // 定时刷新倒计时
    this.timer = setInterval(() => { this.revision++ }, 30000)
  }

  aboutToDisappear(): void {
    if (this.timer > 0) {
      clearInterval(this.timer)
    }
  }

  onPageShow(): void {
    this.refreshGoals()
    this.loadSettings()
  }

  async loadSettings(): Promise<void> {
    const s: SettingsModel = await SettingsStore.load()
    I18n.setLanguage(s.language)
    this.colorScheme = s.colorScheme
    this.revision++
  }

  async refreshGoals(): Promise<void> {
    const goals = await AppViewModel.loadGoals()
    this.goals = goals
    if (goals.length === 0) {
      this.selectedGoalId = ''
      this.currentTree = []
      this.revision++
      return
    }
    if (this.selectedGoalId.length === 0 || goals.findIndex((g: Goal) => g.id === this.selectedGoalId) < 0) {
      this.selectedGoalId = goals[0].id
    }
    await this.loadSelectedGoal(goals)
    this.revision++
  }

  private async loadSelectedGoal(goals: Goal[]): Promise<void> {
    const goal = goals.find((g: Goal) => g.id === this.selectedGoalId)
    if (goal === undefined) {
      this.currentTree = []
      return
    }
    this.selectedGoalName = goal.name
    this.selectedGoalColor = goal.colorHex
    this.selectedEndDate = goal.endDate
    this.selectedEndPrecise = goal.endDatePreciseToHour
    this.selectedCountingMode = goal.progressCountingMode
    this.currentTree = await AppViewModel.loadGoalTree(goal.id)
  }

  private async selectGoal(id: string): Promise<void> {
    this.selectedGoalId = id
    this.expanded = new Set<string>()
    await this.loadSelectedGoal(this.goals)
    this.revision++
  }

  // ===== 构建行与进度 =====
  private buildRows(): TaskRow[] {
    return AppViewModel.flatten(this.currentTree, this.expanded)
  }

  private computeProgress(): GoalProgressView {
    const temp = new Goal()
    temp.tasks = this.currentTree
    temp.progressCountingMode = this.selectedCountingMode
    return AppViewModel.goalProgress(temp)
  }

  /** 目标进度比例（0~1，封顶 100%） */
  private goalFraction(): number {
    return Math.min(this.computeProgress().fraction, 1)
  }

  private goalCompletedWeight(): number {
    return this.computeProgress().completedWeight
  }

  private goalTotalItems(): number {
    return this.computeProgress().totalItems
  }

  /** 进度型任务的 "当前/总量" 文案 */
  private taskProgressLabel(task: TaskItem): string {
    const p = AppViewModel.effectiveProgress(task)
    return `${Math.round(p.current)}/${Math.round(p.total)}`
  }

  /** 进度型任务的百分比（0~100） */
  private taskProgressPercent(task: TaskItem): number {
    const p = AppViewModel.effectiveProgress(task)
    return p.total > 0 ? Math.min(p.current / p.total, 1) * 100 : 0
  }

  private toggleExpand(id: string): void {
    if (this.expanded.has(id)) {
      this.expanded.delete(id)
    } else {
      this.expanded.add(id)
    }
    this.revision++
  }

  private cycleStatus(task: TaskItem): void {
    switch (task.status) {
      case 'notDone':
        task.status = 'done'
        break
      case 'done':
        task.status = 'halfDone'
        break
      case 'halfDone':
        task.status = 'deleted'
        break
      case 'deleted':
        task.status = 'notDone'
        break
    }
    AppViewModel.saveTask(task)  // fire and forget
    this.revision++
  }

  private adjustProgress(task: TaskItem, delta: number): void {
    const p = AppViewModel.effectiveProgress(task)
    let next = task.currentAmount + delta
    task.currentAmount = Math.min(Math.max(next, 0), task.totalAmount)
    AppViewModel.saveTask(task)
    this.revision++
  }

  private isDeletedTask(task: TaskItem): boolean {
    return AppViewModel.isDeleted(task)
  }

  private statusSymbol(s: TaskStatus): Resource {
    switch (s) {
      case 'done':
        return $r('sys.symbol.checkmark_circle_fill')
      case 'halfDone':
        return $r('sys.symbol.circle_lefthalf_inset_filled')
      case 'deleted':
        return $r('sys.symbol.trash')
      default:
        return $r('sys.symbol.circle')
    }
  }

  private statusColor(s: TaskStatus): string {
    switch (s) {
      case 'done':
        return D.colorSuccess
      case 'halfDone':
        return D.colorWarning
      case 'deleted':
        return D.colorDanger
      default:
        return this.tTertiary()
    }
  }

  // ===== 编辑打开/保存 =====
  private openAddTopTask(): void {
    this.taskBuf.mode = 'new'
    this.taskBuf.id = ''
    this.taskBuf.goalId = this.selectedGoalId
    this.taskBuf.parentId = undefined
    this.taskBuf.name = ''
    this.taskBuf.type = 'single'
    this.taskBuf.status = 'notDone'
    this.taskBuf.totalAmount = 0
    this.taskBuf.currentAmount = 0
    this.taskBuf.colorHex = undefined
    this.taskBuf.hasReminder = false
    this.taskBuf.reminderMs = Date.now()
    this.taskBuf.repeatRule = 'never'
    this.taskBuf.weekdays = []
    this.taskSheetVisible = true
  }

  private openAddChild(parent: TaskItem): void {
    this.taskBuf.mode = 'newChild'
    this.taskBuf.id = ''
    this.taskBuf.goalId = this.selectedGoalId
    this.taskBuf.parentId = parent.id
    this.taskBuf.name = ''
    this.taskBuf.type = 'single'
    this.taskBuf.status = 'notDone'
    this.taskBuf.totalAmount = 0
    this.taskBuf.currentAmount = 0
    this.taskBuf.colorHex = undefined
    this.taskBuf.hasReminder = false
    this.taskBuf.reminderMs = Date.now()
    this.taskBuf.repeatRule = 'never'
    this.taskBuf.weekdays = []
    this.taskSheetVisible = true
  }

  private openEditTask(task: TaskItem): void {
    this.taskBuf.mode = 'edit'
    this.taskBuf.id = task.id
    this.taskBuf.goalId = this.selectedGoalId
    this.taskBuf.parentId = task.parentTaskId
    this.taskBuf.name = task.name
    this.taskBuf.type = task.type
    this.taskBuf.status = task.status
    this.taskBuf.totalAmount = task.totalAmount
    this.taskBuf.currentAmount = task.currentAmount
    this.taskBuf.colorHex = task.colorHex
    this.taskBuf.hasReminder = task.reminderDate !== undefined
    this.taskBuf.reminderMs = task.reminderDate !== undefined ? task.reminderDate : Date.now()
    this.taskBuf.repeatRule = task.repeatRule === undefined ? 'never' : task.repeatRule
    this.taskBuf.weekdays = task.effectiveWeekdays()
    this.taskSheetVisible = true
  }

  private async saveTaskEditor(): Promise<void> {
    const buf = this.taskBuf
    const name = buf.name.trim()
    if (name.length === 0) {
      promptAction.showToast({ message: I18n.t('tasks.nameRequired') })
      return
    }
    const reminderMs = buf.hasReminder ? buf.reminderMs : undefined
    const repeatRule = buf.hasReminder ? buf.repeatRule : undefined
    const weekdays = buf.hasReminder && buf.repeatRule === 'custom' ? buf.weekdays.join(',') : undefined

    if (buf.mode === 'edit') {
      const task = AppViewModel.findInTree(this.currentTree, buf.id)
      if (task !== undefined) {
        task.name = name
        task.type = buf.type
        task.status = buf.status
        task.totalAmount = Math.max(0, buf.totalAmount)
        task.currentAmount = Math.min(Math.max(buf.currentAmount, 0), task.totalAmount)
        task.colorHex = buf.colorHex
        task.reminderDate = reminderMs
        task.repeatRule = repeatRule
        task.customWeekdaysRaw = weekdays
        await AppViewModel.saveTask(task)
        await this.syncReminder(task)
      }
    } else {
      const parentNode = buf.parentId !== undefined ? AppViewModel.findInTree(this.currentTree, buf.parentId) : undefined
      const directChildren: TaskItem[] = buf.parentId !== undefined ? (parentNode !== undefined ? parentNode.subtasks : []) : this.currentTree
      const sortOrder = AppViewModel.nextSortOrderOfDirectChildren(directChildren)
      const t = await AppViewModel.addTask(name, buf.type, this.selectedGoalId, buf.parentId,
        buf.status, Math.max(0, buf.totalAmount), Math.min(Math.max(buf.currentAmount, 0), Math.max(0, buf.totalAmount)),
        reminderMs, repeatRule, weekdays, sortOrder)
      if (buf.parentId !== undefined) {
        this.expanded.add(buf.parentId)
      }
      // 新任务已由 addTask 落库；刷新树使其出现在视图
    }
    this.taskSheetVisible = false
    await this.loadSelectedGoal(this.goals)
    this.revision++
  }

  /** 同步任务提醒（编辑场景）：有提醒 → 重新调度；无提醒 → 取消 */
  private async syncReminder(task: TaskItem): Promise<void> {
    try {
      if (task.reminderDate !== undefined) {
        const gname = await AppViewModel.goalNameOf(this.selectedGoalId)
        await ReminderService.schedule(task, gname)
      } else {
        await ReminderService.cancel(task.id)
      }
    } catch (e) {
      // 忽略提醒调度失败（通知权限被拒等）
    }
  }

  // ===== 目标编辑打开/保存 =====
  private openAddGoal(): void {
    this.goalBuf.isNew = true
    this.goalBuf.id = ''
    this.goalBuf.name = ''
    this.goalBuf.colorHex = 'auto'
    this.goalBuf.countingMode = 'allTasks'
    this.goalSheetVisible = true
  }

  private openEditGoal(g: Goal): void {
    this.goalBuf.isNew = false
    this.goalBuf.id = g.id
    this.goalBuf.name = g.name
    this.goalBuf.colorHex = g.colorHex
    this.goalBuf.countingMode = g.progressCountingMode
    this.goalSheetVisible = true
  }

  private async saveGoalEditor(): Promise<void> {
    const name = this.goalBuf.name.trim()
    if (name.length === 0) {
      promptAction.showToast({ message: I18n.t('goals.nameRequired') })
      return
    }
    if (this.goalBuf.isNew) {
      const g = await AppViewModel.createGoal(name, this.goalBuf.colorHex, undefined, undefined, undefined, false, false, this.goalBuf.countingMode)
      this.goalSheetVisible = false
      await this.refreshGoals()
      this.selectGoal(g.id)
    } else {
      const g = this.goals.find((it: Goal) => it.id === this.goalBuf.id)
      if (g !== undefined) {
        g.name = name
        g.colorHex = this.goalBuf.colorHex
        g.progressCountingMode = this.goalBuf.countingMode
        await AppViewModel.updateGoal(g)
        this.goalSheetVisible = false
        await this.refreshGoals()
      }
    }
    this.revision++
  }

  private confirmDeleteGoal(g: Goal): void {
    AlertDialog.show({
      title: I18n.t('goals.delete'),
      message: I18n.t('goals.deleteConfirm', g.name),
      primaryButton: {
        value: I18n.t('common.cancel'),
        action: () => { }
      },
      secondaryButton: {
        value: I18n.t('common.delete'),
        fontColor: D.colorDanger,
        action: async () => {
          await AppViewModel.deleteGoal(g.id)
          if (this.selectedGoalId === g.id) {
            this.selectedGoalId = ''
          }
          await this.refreshGoals()
          this.revision++
        }
      }
    })
  }

  private confirmDelete(task: TaskItem): void {
    AlertDialog.show({
      title: I18n.t('tasks.delete'),
      message: I18n.t('tasks.deleteConfirm', task.name),
      primaryButton: {
        value: I18n.t('common.cancel'),
        action: () => { }
      },
      secondaryButton: {
        value: I18n.t('common.delete'),
        fontColor: D.colorDanger,
        action: async () => {
          const pid = task.parentTaskId
          await AppViewModel.deleteTask(task.id)
          this.removeFromTree(this.currentTree, task.id)
          if (pid !== undefined) {
            // 刷新以免遗留空父容器（若已被删除则忽略）
          }
          await this.loadSelectedGoal(this.goals)
          this.revision++
        }
      }
    })
  }

  private removeFromTree(tree: TaskItem[], id: string): void {
    for (let i = 0; i < tree.length; i++) {
      if (tree[i].id === id) {
        tree.splice(i, 1)
        return
      }
      this.removeFromTree(tree[i].subtasks, id)
    }
  }

  // ===== 主题辅助 =====
  private isDark(): boolean {
    return Theme.dark(this.colorScheme)
  }

  private pal(): ThemePalette {
    return Theme.palette(this.isDark())
  }

  private tPrimary(): string {
    return this.pal().textPrimary
  }

  private tSecondary(): string {
    return this.pal().textSecondary
  }

  private tTertiary(): string {
    return this.pal().textTertiary
  }

  private resolveColor(hex: string): string {
    if (hex === 'auto' || hex.length === 0) {
      return this.isDark() ? '#B3B3BC' : '#7C7C7C'
    }
    return hex
  }
}