# Tick · Android（Kotlin + Jetpack Compose）

Tick 待办应用的 Android 官方实现：目标是顶层组织单元，支持无限层级子任务、递归进度汇总、
本地通知与重复提醒、AI 任务生成与多轮对话、8 套厂商皮肤运行时切换、数据导出/导入备份。

## 技术栈

- 语言：Kotlin 2.0+（Compose Multiplatform 风格的单模块 App）
- UI：Jetpack Compose + Material 3（`enum Skin` 驱动 8 套 `ColorScheme`）
- 数据库：Room（KSP 注解处理器）
- 网络：OkHttp（OpenAI 兼容 AI API）
- 依赖注入 / 导航：无第三方框架，使用 ViewModel + 状态路由
- 最低/目标/编译 SDK：26 / 35 / 35
- 包名：`com.tick.app.android`

## 目录结构

```
android/
├─ settings.gradle.kts
├─ build.gradle.kts
├─ gradle.properties
├─ gradle/libs.versions.toml          # 版本目录
├─ gradle/wrapper/…                   # Gradle Wrapper（Gradle 8.7）
└─ app/
   ├─ build.gradle.kts
   ├─ proguard-rules.pro
   └─ src/main/
      ├─ AndroidManifest.xml
      ├─ res/                          # 图标 / 字符串 / 主题
      └─ java/com/tick/app/android/
         ├─ TickApplication.kt         # Application
         ├─ model/                     # Goal / TaskItem / Enums / AIModels
         ├─ data/                      # Room DB、DAO、Repository、Settings、SecurePrefs、AI 会话
         ├─ domain/                    # ProgressEngine（递归进度引擎，忠实移植 iOS）
         ├─ ai/                        # AIService（OpenAI 兼容 + JSON envelope）
         ├─ doc/                       # DocumentTextExtractor（txt/md/pdf）
         ├─ notification/              # ReminderScheduler / ReminderReceiver（重复提醒）
         ├─ backup/                    # DataBackupManager（导出/导入/备份）
         └─ ui/
            ├─ MainActivity.kt         # 入口 + 抽屉导航 + 全局装配
            ├─ theme/                  # enum Skin + 8 套 colorScheme + 本地化字符串
            ├─ util/                   # 倒计时 / 颜色 / 图标
            ├─ viewmodel/              # TickViewModel（状态与领域操作）
            └─ screens/               # 主界面 / 目标编辑 / 任务编辑 / 设置 / AI 聊天
```

## 构建

前置：JDK 17、Android SDK 35（`compileSdk`）。`local.properties` 中 `sdk.dir` 指向 SDK 根目录
（或用 Android Studio 自动配置）。

命令行构建：

```bash
# 在 android/ 目录下（首次会自动下载 Gradle 8.7 与依赖）
gradlew.bat assembleDebug
```

生成的 APK 位于 `app/build/outputs/apk/debug/app-debug.apk`。

> 若发行版开启混淆请同步 `proguard-rules.pro`；Room/OkHttp/Compose 的混淆规则已在其中列出。

## 核心机制

- **任务接管**：有子任务时，单项状态与进度任务总量/当前值变为只读，由直接子任务递归折算汇总；
  全部有效子任务删除后接管解除，保留删除前的手动值。
- **递归进度引擎**（`domain/ProgressEngine.kt`）：`allTasks` / `leafTasks` 两种统计模式；
  删除态子任务整棵子树不计入；`effectiveStatus`/`effectiveProgress`/`childContribution`；
  颜色/图标/起止日期沿父链继承到 Goal。
- **提醒**：`ReminderReceiver` + `AlarmManager.setExactAndAllowWhileIdle`，支持 每天/每周/每月/自定义周几。
- **AI**：Android 厂商助手无公开 API，故不内嵌；设置页提供 OpenAI 兼容 API 配置
  （默认 Base `https://api.deepseek.com/v1`、模型 `deepseek-chat`、temperature 0.3）。
  附件支持 `.txt / .md / .pdf`（PDF 用 pdfbox 提取文本，失败给友好提示）。
  AI 返回 JSON envelope：`{"generate":true,"tasks":[{"name":"","children":[]}],"message":""}`
  或 `{"generate":false,"message":""}`；`generate=true` 时任务树写入当前目标（不展示）。
  系统提示词明确禁止生成"了解xxx/阅读附件/整理要点"类空泛任务。
- **皮肤**：`enum Skin` 内置 8 套配色（翡翠绿 / 蔚蓝 / 靛蓝 / 柠檬黄 / 天蓝 / 活力橙 /
  玻璃橙半透明 / 湖蓝），名称均为颜色名（`id` 保持稳定），在设置页运行时切换。
- **备份**：设置页导出/导入 JSON（SAF 文件选择器），含全部目标、任务树与设置。