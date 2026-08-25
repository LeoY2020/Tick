import Foundation
import FoundationModels
import zlib

/// 一条对话消息（AI 聊天 / 生成任务 共用）
struct ChatMessage: Sendable, Identifiable {
    enum Role: String { case user, assistant }

    let id: UUID
    let role: Role
    let text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

/// AI 生成的任务树节点（宽容解码：缺字段不失败）
struct TaskNode: Decodable {
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

    /// 聊天系统提示词（要求自然回答，不出 JSON）
    private static let chatSystemPrompt = """
    你是一个耐心、简洁的中文助手，帮助用户整理任务与计划。
    根据对话上下文与可选的附件内容自然回答；需要整理成清单时，用清晰的标题和列表。
    不要用 markdown 代码块包裹 JSON 输出。
    """

    /// 任务生成系统提示词：要求模型只输出 JSON
    private static let taskSystemPrompt = """
    你是一个任务清单生成助手。你会收到一份对话记录和可选的文档附件内容，请把它解析成一棵嵌套的任务清单。
    严格只输出一个 JSON 数组，不要输出任何其他文字、注释或解释。
    数组元素的格式为 {"name":"任务名","children":[{"name":"子任务名"}]}。
    层级规则：一级标题对应顶层任务，二级标题对应其子任务，标题层级越深嵌套越深；
    普通的待办行或段落作为叶子任务，放入合适的父任务下；如果没有标题结构，把每一行当作一个顶层任务。
    """

    /// 生成一句对话回复（多轮上下文携带在 history 中）
    static func chatReply(history: [ChatMessage],
                          attachmentText: String?,
                          model: AIModel,
                          apiKey: String?,
                          customBaseURL: String?,
                          customModel: String?) async throws -> String {
        let merged = try mergedHistory(history, attachmentText: attachmentText)
        return try await requestText(systemPrompt: chatSystemPrompt,
                                     history: merged,
                                     model: model,
                                     apiKey: apiKey,
                                     customBaseURL: customBaseURL,
                                     customModel: customModel)
    }

    /// 根据对话记录 + 可选附件生成嵌套任务树
    static func generateTaskTree(from history: [ChatMessage],
                                 attachmentText: String?,
                                 model: AIModel,
                                 apiKey: String?,
                                 customBaseURL: String?,
                                 customModel: String?) async throws -> [TaskNode] {
        let merged = try mergedHistory(history, attachmentText: attachmentText)
        let response = try await requestText(systemPrompt: taskSystemPrompt,
                                             history: merged,
                                             model: model,
                                             apiKey: apiKey,
                                             customBaseURL: customBaseURL,
                                             customModel: customModel)
        return try parseTaskNodes(from: response)
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
        let response = try await session.respond(to: transcript(history))
        return response.content
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

    /// 设备端模型上下文较小，且需为生成的 JSON 输出预留空间。
    /// 输入（含附件）超预算即丢弃最早对话并截断最新一条，避免「transcript exceeded context size」。
    private static let transcriptCharBudget = 3_000

    /// 将多轮对话折叠为单一 transcript（设备端模型是单轮 API，用文本拼接保留上下文）。
    /// 设备端模型上下文有限：保留最新的对话，逐条累计直至预算用尽即停止丢弃更旧的；
    /// 最新一条即便超预算也截断保留，保证总有内容可回复。
    private static func transcript(_ history: [ChatMessage]) -> String {
        let budget = transcriptCharBudget
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

    /// 从模型返回文本中抽取出 JSON 数组并解析为任务树
    private static func parseTaskNodes(from rawText: String) throws -> [TaskNode] {
        let text = stripCodeFences(rawText)
        // 抽取第一个 '[' 到最后一个 ']'
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"), start < end else {
            throw AIServiceError.invalidJSON
        }
        let json = text[start...end]
        guard let data = json.data(using: .utf8) else { throw AIServiceError.invalidJSON }
        guard let nodes = try? JSONDecoder().decode([TaskNode].self, from: data) else {
            throw AIServiceError.invalidJSON
        }
        // 过滤空名节点
        let cleaned = nodes.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !cleaned.isEmpty else { throw AIServiceError.emptyResult }
        return cleaned
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