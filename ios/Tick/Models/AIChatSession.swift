import Foundation
import SwiftData

/// AI 聊天历史记录：持久化一次会话的消息与附件快照，供「AI 历史」恢复。
/// 不用非可选 Codable 枚举，避免既有 iCloud 数据迁移崩溃（见工程约定）。
@Model
final class AIChatSession {
    var id: UUID = UUID()
    /// 会话标题（取首条用户消息摘要）
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// 消息列表的 JSON 编码（[ChatMessage]）
    var messagesData: Data = Data()
    var messageCount: Int = 0
    var attachmentName: String? = nil
    var attachmentText: String? = nil

    init(id: UUID = UUID(),
         title: String = "",
         createdAt: Date = .now,
         updatedAt: Date = .now,
         messagesData: Data = Data(),
         messageCount: Int = 0,
         attachmentName: String? = nil,
         attachmentText: String? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messagesData = messagesData
        self.messageCount = messageCount
        self.attachmentName = attachmentName
        self.attachmentText = attachmentText
    }

    // MARK: - 助手

    /// 编码消息列表为 Data
    static func encode(_ messages: [ChatMessage]) -> Data {
        (try? JSONEncoder().encode(messages)) ?? Data()
    }

    /// 解码消息列表；失败返回空
    static func decodeMessages(_ data: Data) -> [ChatMessage] {
        guard let list = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return [] }
        return list
    }
}