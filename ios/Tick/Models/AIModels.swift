import Foundation

/// AI 模型（导入文档生成任务清单时使用的模型）。
/// Apple Intelligence 走设备端 FoundationModels 框架（无需 API Key）；
/// 其余需在设置中填写对应 API Key。
enum AIModel: String, CaseIterable, Codable, Identifiable {
    /// Apple Intelligence（设备端，无需 API Key）
    case appleIntelligence
    // 云模型（OpenAI 兼容或以特殊协议调用）
    case qwen       // 千问
    case deepseek   // Deepseek
    case chatgpt    // ChatGPT
    case yuanbao    // 元宝
    case claude     // Claude
    case gemini     // Gemini
    case glm        // GLM
    case kimi       // Kimi
    case ernie      // 文心
    case grok       // Grok
    case stepfun    // 阶跃星辰
    case minimax    // MiniMax
    case custom     // 自定义

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .appleIntelligence: return "Apple Intelligence"
        case .qwen: return "千问"
        case .deepseek: return "DeepSeek"
        case .chatgpt: return "ChatGPT"
        case .yuanbao: return "元宝"
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .glm: return "GLM"
        case .kimi: return "Kimi"
        case .ernie: return "文心"
        case .grok: return "Grok"
        case .stepfun: return "阶跃星辰"
        case .minimax: return "MiniMax"
        case .custom: return "自定义"
        }
    }

    /// 是否需要 API Key（Apple Intelligence 设备端模型不需要）
    var requiresAPIKey: Bool {
        self != .appleIntelligence
    }
}