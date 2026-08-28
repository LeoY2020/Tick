import Foundation
import FoundationModels
import zlib

/// 一条对话消息（AI 聊天 / 生成任务 共用）。
/// Codable：持久化到 AIChatSession 供历史记录恢复
struct ChatMessage: Sendable, Codable, Identifiable {
    enum Role: String, Codable { case user, assistant }

    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, text: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

/// 一次聊天回复的结构化结果：是否生成任务、生成的任务树、以及展示给用户看的文字。
/// 由模型输出 JSON envelope 解析而来：generate=true 时 tasks 写入当前目标（不展示），message 展示
struct ChatReply: Sendable {
    var shouldGenerateTasks: Bool = false
    var tasks: [TaskNode] = []
    var message: String = ""
}

/// AI 生成的任务树节点（宽容解码：缺字段不失败）
struct TaskNode: Decodable, Sendable {
    var name: String = ""
    var children: [TaskNode] = []

    private enum CodingKeys: String, CodingKey { case name, children }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        children = (try? container.decode([TaskNode].self, forKey: .children)) ?? []
    }
}

/// AI 服务错误
enum AIServiceError: LocalizedError {
    case missingAPIKey
    case appleIntelligenceUnavailable(String)
    case network(String)
    case badResponse
    case emptyResult
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在 设置 → AI 模型 中填写该模型的 API Key"
        case .appleIntelligenceUnavailable(let reason):
            return "Apple Intelligence 不可用：\(reason)"
        case .network(let detail):
            return "网络请求失败：\(detail)"
        case .badResponse:
            return "模型服务返回了异常响应"
        case .emptyResult:
            return "模型未生成有效内容"
        case .invalidJSON:
            return "无法解析模型返回的任务清单"
        }
    }
}

/// AI 服务：根据所选模型（Apple Intelligence 本地 / 云模型）进行多轮对话与任务树生成。
enum AIService {

    /// 聊天系统提示词：要求输出 JSON envelope（任务入库 + 展示文字），由 AI 自行判断是否生成任务。
    /// 生成任务的两类依据：①文档附件正文（用户消息"附件内容："之后）；②用户在纯对话中描述的需求（无需附件）。
    private static let chatSystemPrompt = """
    你是一个严谨的中文任务规划助手。你可以依据以下两类信息来生成具体、可执行、有信息量的分层任务清单：
    1. 文档附件内容（通常在用户消息的"附件内容："之后）：从中提炼真实要点建任务，按章节、核心观点、待办事项拆分。
    2. 用户在对话中描述的任务与计划：即使没有附件，也依据对话上下文，把用户提出的需求、事项、时间安排等整理成分层任务树。

    硬性要求：
    1. 任务名要具体明确（如"核对第三章数据""完成市场分析草稿"），严禁生成"了解xxx""阅读附件""整理要点"这类空泛无信息的任务。
    2. 一级任务概括主题，二级任务给出具体动作或子步骤，层级嵌套。
    3. 只要用户明确要求"生成/整理任务"（无论仅提供附件、还是仅在对话中描述需求），都应 generate=true 并基于可用信息生成任务树。
    4. 仅当既没有附件正文、也没有明确的对话需求、实在无法提炼时，才返回 generate=false 并说明原因。

    你必须严格只输出一个 JSON 对象，不要输出 markdown 代码块，也不要输出 JSON 以外的任何文字：
    1. 用户要求生成/整理任务且能提炼要点时，输出：
    {"generate": true, "tasks": [{"name":"一级任务","children":[{"name":"二级任务"}]}], "message": "给用户看的一句话中文说明"}
    2. 用户要求生成任务、但既无附件正文也无明确对话需求、无法生成有意义任务时，输出：
    {"generate": false, "message": "我目前还缺少足够的信息来生成有意义的任务。你可以上传带文字的 PDF / Word / 文本，或在对话里描述你想规划的事项。"}
    3. 其他普通闲聊（未要求生成任务）时，输出：
    {"generate": false, "message": "你的回复文字"}
    """

    /// 与 AI 聊天，返回结构化结果（AI 自行判断是否生成任务）
    static func chatReply(history: [ChatMessage],
                          attachmentText: String?,
                          model: AIModel,
                          apiKey: String?,
                          customBaseURL: String?,
                          customModel: String?) async throws -> ChatReply {
        let merged = try mergedHistory(history, attachmentText: attachmentText)
        let response = try await requestText(systemPrompt: chatSystemPrompt,
                                             history: merged,
                                             model: model,
                                             apiKey: apiKey,
                                             customBaseURL: customBaseURL,
                                             customModel: customModel)
        return parseChatReply(response)
    }

    // MARK: - 请求分发

    private static func requestText(systemPrompt: String,
                                    history: [ChatMessage],
                                    model: AIModel,
                                    apiKey: String?,
                                    customBaseURL: String?,
                                    customModel: String?) async throws -> String {
        switch model {
        case .appleIntelligence:
            guard #available(iOS 26.0, macOS 26.0, *) else {
                throw AIServiceError.appleIntelligenceUnavailable("需要 iOS 26 及以上系统")
            }
            return try await onDeviceRequest(systemPrompt: systemPrompt, history: history)
        default:
            guard let apiKey, !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }
            return try await cloudRequest(systemPrompt: systemPrompt,
                                          history: history,
                                          apiKey: apiKey,
                                          model: model,
                                          customBaseURL: customBaseURL,
                                          customModel: customModel)
        }
    }

    // MARK: - Apple Intelligence（设备端）

    @available(iOS 26.0, macOS 26.0, *)
    private static func onDeviceRequest(systemPrompt: String, history: [ChatMessage]) async throws -> String {
        // 设备端模型可用性检查（不可用原因不细拆，避免各 SDK 版本子类型差异）
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable:
            throw AIServiceError.appleIntelligenceUnavailable("请在系统设置中开启 Apple Intelligence，或当前设备暂不支持")
        @unknown default:
            throw AIServiceError.appleIntelligenceUnavailable("当前设备不支持")
        }

        let session = LanguageModelSession(instructions: systemPrompt)
        // Apple Intelligence 可能由设备端或云端执行：云端上下文较大、设备端较小。
        // 先用完整上下文尝试，仅当模型判定「上下文超限」时，从大到小降低输入预算重试，
        // 避免在云端本可容纳的场景下过早截断。
        var attempt = 0
        while true {
            do {
                let response = try await session.respond(
                    to: transcript(history, budget: deviceTranscriptBudgets[min(attempt, deviceTranscriptBudgets.count - 1)])
                )
                return response.content
            } catch {
                guard isContextOverflow(error), attempt + 1 < deviceTranscriptBudgets.count else { throw error }
                attempt += 1
            }
        }
    }

    // MARK: - 云模型

    private static func cloudRequest(systemPrompt: String,
                                     history: [ChatMessage],
                                     apiKey: String,
                                     model: AIModel,
                                     customBaseURL: String?,
                                     customModel: String?) async throws -> String {
        // 自定义模型地址必填
        if model == .custom {
            guard let customBaseURL, !customBaseURL.isEmpty else { throw AIServiceError.missingAPIKey }
        }

        let spec = providerSpec(for: model, customBaseURL: customBaseURL, customModel: customModel)
        let modelID = modelID(for: model, customModel: customModel)
        return try await sendCloudRequest(spec: spec,
                                          apiKey: apiKey,
                                          systemPrompt: systemPrompt,
                                          history: history,
                                          modelID: modelID)
    }

    // MARK: - 请求构造 / 发送

    /// 请求体类型（OpenAI 兼容 / Anthropic / Gemini 三种协议）
    private enum ProviderKind { case openAICompatible, anthropic, gemini }

    private struct ProviderSpec {
        let kind: ProviderKind
        let url: URL
        let apiKeyHeaderField: String?  // nil = 放到 URL query（Gemini）

        /// OpenAI 兼容版 ProviderSpec 便捷构造（供顶层 switch 的 `.oa(...)` 上下文类型推断匹配本类型）
        static func oa(_ urlString: String) -> ProviderSpec {
            ProviderSpec(kind: .openAICompatible, url: URL(string: urlString)!, apiKeyHeaderField: "Authorization")
        }
    }

    private static func providerSpec(for model: AIModel,
                                     customBaseURL: String?,
                                     customModel: String?) -> ProviderSpec {
        switch model {
        case .appleIntelligence:
            // 不会走到这里
            return ProviderSpec(kind: .openAICompatible,
                                url: URL(string: "https://example.invalid")!,
                                apiKeyHeaderField: "Authorization")
        case .qwen:
            return .oa("https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")
        case .deepseek:
            return .oa("https://api.deepseek.com/chat/completions")
        case .chatgpt:
            return .oa("https://api.openai.com/v1/chat/completions")
        case .yuanbao:
            return .oa("https://api.hunyuan.cloud.tencent.com/v1/chat/completions")
        case .claude:
            return ProviderSpec(kind: .anthropic,
                                url: URL(string: "https://api.anthropic.com/v1/messages")!,
                                apiKeyHeaderField: "x-api-key")
        case .gemini:
            return ProviderSpec(kind: .gemini,
                                url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/")!,
                                apiKeyHeaderField: nil)
        case .glm:
            return .oa("https://open.bigmodel.cn/api/paas/v4/chat/completions")
        case .kimi:
            return .oa("https://api.moonshot.cn/v1/chat/completions")
        case .ernie:
            return .oa("https://qianfan.baidubce.com/v2/chat/completions")
        case .grok:
            return .oa("https://api.x.ai/v1/chat/completions")
        case .stepfun:
            return .oa("https://api.stepfun.com/v1/chat/completions")
        case .minimax:
            return .oa("https://api.minimax.chat/v1/chat/completions")
        case .custom:
            // 去掉所有空白 / 换行，避免非法 URL 导致强制解包崩溃
            let baseURL = (customBaseURL ?? "")
                .components(separatedBy: .whitespacesAndNewlines)
                .joined()
            let url = baseURL.hasSuffix("/chat/completions")
                ? baseURL
                : baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
            return ProviderSpec(kind: .openAICompatible,
                                url: URL(string: url) ?? URL(string: "https://example.invalid")!,
                                apiKeyHeaderField: "Authorization")
        }
    }

    /// 模型标识（OpenAI 兼容 / Anthropic 用）
    private static func modelID(for model: AIModel, customModel: String?) -> String {
        switch model {
        case .appleIntelligence: return ""
        case .qwen: return "qwen-plus"
        case .deepseek: return "deepseek-chat"
        case .chatgpt: return "gpt-4o-mini"
        case .yuanbao: return "hunyuan-turbo"
        case .claude: return "claude-sonnet-4-20250514"
        case .gemini: return "gemini-2.0-flash"
        case .glm: return "glm-4-flash"
        case .kimi: return "moonshot-v1-8k"
        case .ernie: return "ernie-4.0-turbo-8k"
        case .grok: return "grok-2-latest"
        case .stepfun: return "step-1-8k"
        case .minimax: return "abab6.5s-chat"
        case .custom: return customModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    private static func sendCloudRequest(spec: ProviderSpec,
                                         apiKey: String,
                                         systemPrompt: String,
                                         history: [ChatMessage],
                                         modelID: String) async throws -> String {
        var request = URLRequest(url: spec.url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch spec.kind {
        case .openAICompatible:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: spec.apiKeyHeaderField!)
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: spec.apiKeyHeaderField!)
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .gemini:
            // API Key 放 URL query，见下方
            break
        }

        let body = try makeBody(kind: spec.kind, systemPrompt: systemPrompt, history: history, modelID: modelID)
        request.httpBody = body

        if spec.kind == .gemini {
            var comps = URLComponents(url: spec.url.appendingPathComponent(modelID)
                .appendingPathComponent(":generateContent"),
                resolvingAgainstBaseURL: false)
            comps?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
            request.url = comps?.url
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw AIServiceError.network("HTTP \(http.statusCode)")
        }
        return try parseCloudResponse(data, kind: spec.kind)
    }

    private static func makeBody(kind: ProviderKind,
                                 systemPrompt: String,
                                 history: [ChatMessage],
                                 modelID: String) throws -> Data {
        switch kind {
        case .openAICompatible:
            var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
            for m in history {
                messages.append(["role": m.role == .user ? "user" : "assistant", "content": m.text])
            }
            return try JSONSerialization.data(withJSONObject: ["model": modelID, "messages": messages])
        case .anthropic:
            let msgs = history.map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.text] }
            let body: [String: Any] = [
                "model": modelID,
                "system": systemPrompt,
                "messages": msgs,
                "max_tokens": 2000
            ]
            return try JSONSerialization.data(withJSONObject: body)
        case .gemini:
            let full = systemPrompt + "\n\n" + history.map {
                "\($0.role == .user ? "用户" : "助手")：\($0.text)"
            }.joined(separator: "\n")
            let body: [String: Any] = [
                "contents": [["parts": [["text": full]]]],
                "generationConfig": ["maxOutputTokens": 2000]
            ]
            return try JSONSerialization.data(withJSONObject: body)
        }
    }

    private static func parseCloudResponse(_ data: Data, kind: ProviderKind) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.badResponse
        }
        switch kind {
        case .openAICompatible:
            guard let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.badResponse
            }
            return content
        case .anthropic:
            guard let content = json["content"] as? [[String: Any]] else { throw AIServiceError.badResponse }
            let parts = content.compactMap { $0["text"] as? String }
            guard !parts.isEmpty else { throw AIServiceError.badResponse }
            return parts.joined(separator: "\n")
        case .gemini:
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                throw AIServiceError.badResponse
            }
            let texts = parts.compactMap { $0["text"] as? String }
            guard !texts.isEmpty else { throw AIServiceError.badResponse }
            return texts.joined(separator: "\n")
        }
    }

    // MARK: - 提示词 / 解析

    /// 把附件内容注入为对话首条"用户"消息（无对话、无附件时抛错）
    private static func mergedHistory(_ history: [ChatMessage], attachmentText: String?) throws -> [ChatMessage] {
        var result = history
        if let attachmentText {
            let trimmed = attachmentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.insert(ChatMessage(role: .user, text: "附件内容：\n" + trimmed), at: 0)
            }
        }
        guard !result.isEmpty else { throw AIServiceError.emptyResult }
        return result
    }

    /// Apple Intelligence 可能由设备端或云端执行：云端上下文较大、设备端较小。
    /// 采用从大往小的预算数组，仅当模型判定「context 超限」时逐级回退减少输入重试。
    private static let deviceTranscriptBudgets = [24_000, 12_000, 6_000, 3_000]

    /// 判断是否为「上下文超限」类错误（FoundationModels 返回该描述），以便回退重试
    private static func isContextOverflow(_ error: Error) -> Bool {
        error.localizedDescription.lowercased().contains("context")
    }

    /// 将多轮对话折叠为单一 transcript（设备端模型是单轮 API，用文本拼接保留上下文）。
    /// 保留最新对话，逐条累计直至预算用尽即丢弃更旧的；最新一条即便超预算也截断保留，
    /// 保证总有内容可回复。
    private static func transcript(_ history: [ChatMessage], budget: Int) -> String {
        var result = ""
        // 从最新向旧遍历，prepend 累加，最终保持时间顺序（最新在末尾）
        for msg in history.reversed() {
            let line = "\(msg.role == .user ? "用户" : "助手")：\(msg.text)"
            if result.isEmpty {
                // 最新一条：必保，超预算则截断到预算内
                result = String(line.prefix(budget))
            } else if result.count + line.count > budget {
                break // 更旧的对话丢弃
            } else {
                result = line + "\n" + result
            }
        }
        return result
    }

    /// 解析 chatReply 的 JSON envelope。
    /// 解析失败或非 generate 时，把原文当普通文字回复展示，不强制生成任务（宽容回退）。
    private static func parseChatReply(_ raw: String) -> ChatReply {
        let cleaned = stripCodeFences(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        if let object = jsonObject(from: cleaned),
           let data = object.data(using: .utf8),
           let env = try? JSONDecoder().decode(ChatEnvelope.self, from: data) {
            if env.generate {
                let nodes = env.tasks.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                return ChatReply(shouldGenerateTasks: true,
                                 tasks: nodes,
                                 message: env.message.isEmpty ? "已为你生成 \(nodes.count) 个任务。" : env.message)
            }
            if !env.message.isEmpty {
                return ChatReply(message: env.message)
            }
        }
        return ChatReply(message: raw)
    }

    /// envelope 的宽容解码模型（缺字段不失败）
    private struct ChatEnvelope: Decodable {
        var generate: Bool = false
        var tasks: [TaskNode] = []
        var message: String = ""

        private enum Keys: String, CodingKey { case generate, tasks, message }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            generate = (try? c.decode(Bool.self, forKey: .generate)) ?? false
            tasks = (try? c.decode([TaskNode].self, forKey: .tasks)) ?? []
            message = (try? c.decode(String.self, forKey: .message)) ?? ""
        }
    }

    /// 抽取文本中第一个 '{' 到最后一个 '}' 的 JSON 对象子串（容忍模型附加的零散文字）
    private static func jsonObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end else { return nil }
        return String(text[start...end])
    }

    /// 去掉 ``` 代码围栏（模型有时会把 JSON 包进 Markdown 代码块）
    private static func stripCodeFences(_ text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if let first = lines.first, first.contains("```") {
            lines.removeFirst()
        }
        if let last = lines.last, last.contains("```") {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }
}