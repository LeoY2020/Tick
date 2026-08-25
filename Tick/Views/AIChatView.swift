import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 与 AI 对话的对话框：会话内多轮对话，可上传附件（可选），并由 AI 自行判断是否生成任务。
/// - AI 输出 JSON envelope：generate=true 时把 tasks 写入当前目标（不展示），只展示 message 文字。
/// - 支持「只有文件、无文字生成」：附件上传后直接点发送即可。
/// - 提供「新建聊天」与「AI 历史记录」（AIChatSession 持久化）。
struct AIChatView: View {
    let goal: Goal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \AIChatSession.updatedAt, order: .reverse) private var sessions: [AIChatSession]

    @State private var messages: [ChatMessage] = []
    @State private var currentSession: AIChatSession?
    @State private var inputText = ""
    @State private var isBusy = false
    @State private var attachmentText: String?
    @State private var attachmentName: String?
    @State private var showFileImporter = false
    @State private var showHistory = false
    @State private var errorMessage: String?
    @State private var resultMessage: String?

    private static let documentTypes: [UTType] = [
        .plainText, .text, .pdf,
        UTType(filenameExtension: "md") ?? .plainText,
        UTType(filenameExtension: "markdown") ?? .plainText,
        UTType(filenameExtension: "docx") ?? .plainText,
        UTType(filenameExtension: "doc") ?? .plainText
    ]

    /// 有输入文字或有附件才可发送（支持“只有文件、无文字生成”）
    private var canSend: Bool {
        guard !isBusy else { return false }
        return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachmentText != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                attachmentBanner
                Divider()
                inputBar
            }
            .navigationTitle("AI 对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: newChat) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("新建聊天")
                    .disabled(isBusy)

                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("AI 历史")
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: Self.documentTypes) { result in
                handleAttachmentResult(result)
            }
            .sheet(isPresented: $showHistory) { historySheet }
            .alert("错误", isPresented: errorAlertBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("已完成", isPresented: resultAlertBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(resultMessage ?? "")
            }
            .onDisappear { persistMessages() }
        }
    }

    // MARK: - 聊天消息区

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { msg in
                        bubble(msg)
                    }
                    if isBusy {
                        typingBubble
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: isBusy) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private func bubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == .user
        return HStack(spacing: 10) {
            if isUser { Spacer(minLength: 48) }
            Text(msg.text)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: 300, alignment: .leading)
            if !isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var typingBubble: some View {
        HStack(spacing: 6) {
            ProgressView()
            Text("正在思考…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 附件

    @ViewBuilder
    private var attachmentBanner: some View {
        if let name = attachmentName {
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                Text(name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    attachmentName = nil
                    attachmentText = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("移除附件")
            }
            .font(.footnote)
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private func handleAttachmentResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try DocumentTextExtractor.extractText(from: url)
                attachmentName = url.lastPathComponent
                attachmentText = text
                if !text.isEmpty {
                    messages.append(ChatMessage(role: .assistant,
                                                text: "已读取附件「\(url.lastPathComponent)」，你可以继续跟我讨论，或直接点发送让我生成任务清单。"))
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        case .failure:
            break
        }
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                showFileImporter = true
            } label: {
                Image(systemName: "paperclip")
            }
            .disabled(isBusy)
            .accessibilityLabel("上传附件")

            TextField("和 AI 说点什么…", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(!canSend)
            .accessibilityLabel("发送")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func send() {
        guard canSend else { return }
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 有附件但没输入文字：以隐式指令让 AI 据此生成任务（“只有文件、无文字生成”）
        let userText = raw.isEmpty ? "（仅使用附件）请据此生成任务清单" : raw

        inputText = ""
        isBusy = true
        messages.append(ChatMessage(role: .user, text: userText))

        // 主线程读取设置与密钥快照，供后台任务使用（避免跨隔离访问）
        let settings = SettingsStore.shared
        let model = settings.selectedModel
        let key = KeychainBackupService.shared.loadAPIKey(modelRawValue: model.rawValue)
        let customBaseURL = settings.customBaseURL
        let customModel = settings.customModel
        let history = messages
        let currentAttachment = attachmentText

        Task {
            do {
                let reply = try await AIService.chatReply(history: history,
                                                          attachmentText: currentAttachment,
                                                          model: model,
                                                          apiKey: key,
                                                          customBaseURL: customBaseURL,
                                                          customModel: customModel)
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, text: reply.message))
                    if reply.shouldGenerateTasks && !reply.tasks.isEmpty {
                        insertTaskTree(reply.tasks)
                        resultMessage = "已为「\(goal.name)」生成 \(reply.tasks.count) 个任务"
                    }
                    isBusy = false
                    persistMessages()
                }
            } catch {
                await MainActor.run {
                    isBusy = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    // MARK: - 任务树写入

    /// 递归把任务树写入当前目标
    private func insertTaskTree(_ nodes: [TaskNode], parent: TaskItem? = nil) {
        for node in nodes {
            let name = node.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let task = TaskItem(name: name, type: .single, totalAmount: 1)
            context.insert(task)
            if let parent {
                task.attach(to: parent)
                task.sortOrder = (parent.subtasks.map(\.sortOrder).max() ?? -1) + 1
            } else {
                task.attach(to: goal)
                task.sortOrder = (goal.tasks.map(\.sortOrder).max() ?? -1) + 1
            }
            if !node.children.isEmpty {
                insertTaskTree(node.children, parent: task)
            }
        }
        // 全树插入完毕后再保存并备份
        if parent == nil {
            try? context.save()
            DataBackupManager.shared.backupAppData(context: context)
        }
    }

    // MARK: - 历史记录与新建

    private var historySheet: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    Button {
                        load(session)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title.isEmpty ? "对话" : session.title)
                            Text("\(session.messageCount) 条消息")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteSessions)
            }
            .navigationTitle("AI 历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showHistory = false }
                }
            }
        }
    }

    private func newChat() {
        persistMessages()
        currentSession = nil
        messages = []
        attachmentText = nil
        attachmentName = nil
        inputText = ""
    }

    private func load(_ session: AIChatSession) {
        currentSession = session
        messages = AIChatSession.decodeMessages(session.messagesData)
        attachmentName = session.attachmentName
        attachmentText = session.attachmentText
        inputText = ""
        showHistory = false
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sessions[index])
        }
        try? context.save()
    }

    /// 把当前消息持久化到 AIChatSession（无消息则不产生空会话）
    private func persistMessages() {
        guard !messages.isEmpty else { return }
        let session = currentSession ?? {
            let new = AIChatSession()
            context.insert(new)
            currentSession = new
            return new
        }()
        session.messagesData = AIChatSession.encode(messages)
        session.messageCount = messages.count
        session.title = messages.first(where: { $0.role == .user })?.text.replacingOccurrences(of: "\n", with: " ") ?? "对话"
        session.attachmentName = attachmentName
        session.attachmentText = attachmentText
        session.updatedAt = .now
        try? context.save()
    }

    // MARK: - 弹窗绑定

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var resultAlertBinding: Binding<Bool> {
        Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )
    }
}

#Preview {
    // 预览占位：AIChatView 需要一个 goal，这里用空容器避免编译错误
    NavigationStack {
        Text("AIChatView")
    }
}