# Tick · 跨平台待办应用

一套「目标 → 无限层级任务」的待办应用，按平台分目录，各自采用对应系统的原生设计语言与官方推荐语言实现。

## 目录结构

| 目录 | 平台 | 语言 / 框架 | 设计语言 |
|---|---|---|---|
| `ios/` | iOS | Swift / SwiftUI | Apple Human Interface Guidelines |
| `macos/` | macOS | Swift / SwiftUI | Apple HIG |
| `android/` | Android（8 家皮肤合一） | Kotlin / Jetpack Compose | Material 3 + 各家皮肤主题 |
| `windows/` | Windows | C# / WinUI 3 | Fluent Design System |
| `harmonyos/` | HarmonyOS | ArkTS / ArkUI | HarmonyOS Design |
| `linux/` | Linux（Debian / Arch / RedHat） | C++ / Qt 6 | 自适应 GNOME / KDE 主题 |

Android 皮肤（同一套 Kotlin 代码，编译期切换主题 skin）：

- ColorOS（OPPO）
- One UI（三星）
- OriginOS（vivo）
- realme UI（realme）
- Flyme（魅族）
- MIUI（小米）
- HyperOS（小米澎湃）
- MagicOS（荣耀）

## AI 助手集成策略

原则：**系统有公开可用的本地 AI 接口才内嵌；无公开接口的平台不内嵌 AI，由用户自行配置 API。**

| 平台 | 默认 AI | 是否内嵌 | 说明 |
|---|---|---|---|
| iOS / macOS | Apple Intelligence | ✅ 内嵌 | 经 FoundationModels 框架，设备端 + 云端模型，无需 API Key |
| Android 各皮肤 | — | ❌ 自配 | 各厂商助手（小爱/YOYO/Bixby/小布/Jovi/Aicy）无第三方公开大模型 API |
| Windows | Windows Copilot | ⚠️ 可选 | Fluent 风格入口，实际调用走用户配置的 OpenAI 兼容 API |
| HarmonyOS | 小艺（盘古） | ⚠️ 可选 | 需华为开发者资质接入，否则走用户自配 API |
| Linux 各发行版 | — | ❌ 自配 | 无系统级 AI，用户自配 API |

所有平台统一支持 OpenAI 兼容协议的云模型（千问 / DeepSeek / ChatGPT / 元宝 / Claude / Gemini / GLM / Kimi / 文心 / Grok / 阶跃星辰 / MiniMax / 自定义），AI 生成任务、AI 对话、文档解析（文本 / Markdown / PDF / DOCX）能力与 iOS 版对齐。

## 核心功能（各平台对齐 iOS 版）

- 目标（Goal）管理：名称、颜色、图标、起止日期、倒计时
- 无限层级任务树（TaskItem）：单项 / 进度两类，支持半完成、删除态
- 递归进度引擎：全任务 / 仅叶子任务两种统计模式，父任务被子任务接管
- 本地通知与重复提醒（每日 / 每周 / 每月 / 自定义周几）
- AI 生成任务 + 多轮对话 + 附件解析
- 深色 / 浅色 / 跟随系统配色，多语言
- 数据持久化与备份（各平台按本机方案：iOS 用 SwiftData + iCloud，Android 用 Room，Linux 用 SQLite，等）

## 构建

各平台目录内包含独立的工程配置与构建说明，详见对应子目录。