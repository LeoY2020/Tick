import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 与 AI 对话 + 可选附件 + 一键生成任务清单的对话框。
/// 点 AI 按钮打开：会话内多轮对话；可通过附件上传文档（可选）；右上「生成任务」把对话/附件转成任务树写入目标。
struct AIChatView: View {
    let goal: Goal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isBusy = false
    @State private var attachmentText: String?
    @State private var attachmentName: String?
    @State private var showFileImporter = false
    @State private var errorMessage: String?
    @State private var resultMessage: String?

    private static let documentTypes: [UTType] = [
        .plainText, .text, .pdf,
        UTType(filenameExtension: "md") ?? .plainText,
        UTType(filenameExtension: "markdown") ?? .plainText,
        UTType(filenameExtension: "docx") ?? .plainText,
        UTType(filenameExtension: "doc") ?? .plainText
    ]

    /// 是否有内容可生成任务（有对话或附件）
    private var canGenerate: Bool {
        !messages.isEmpty || attachmentText != nil
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: generateTasks) {
                        Text(isBusy ? "生成中…" : "生成任务")
                    }
                    .disabled(!canGenerate || isBusy)
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: Self.documentTypes) { result in
                handleAttachmentResult(result)
            }
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
                                                text: "已读取附件「\(url.lastPathComponent)」，你可以继续跟我讨论，或点右上「生成任务」转成清单。"))
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
            .disabled(isBusy || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("发送")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, text: trimmed))
        isBusy = true

        // 主线程读取设置与密钥快照，供后台任务使用（避免跨隔离访问）
        let settings = SettingsStore.shared
        let model = settings.selectedModel
        let key = KeychainBackupService.shared.loadAPIKey(modelRawValue: model.rawValue)
        let customBaseURL = settings.customBaseURL
        let customModel = settings.customModel

        Task {
            do {
                let reply = try await AIService.chatReply(history: messages,
                                                          attachmentText: attachmentText,
                                                          model: model,
                                                          apiKey: key,
                                                          customBaseURL: customBaseURL,
                                                          customModel: customModel)
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, text: reply))
                    isBusy = false
                }
            } catch {
                await MainActor.run {
                    isBusy = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    // MARK: - 生成任务

    private func generateTasks() {
        guard canGenerate, !isBusy else { return }
        isBusy = true

        let settings = SettingsStore.shared
        let model = settings.selectedModel
        let key = KeychainBackupService.shared.loadAPIKey(modelRawValue: model.rawValue)
        let customBaseURL = settings.customBaseURL
        let customModel = settings.customModel
        let history = messages

        Task {
            do {
                let nodes = try await AIService.generateTaskTree(from: history,
                                                                 attachmentText: attachmentText,
                                                                 model: model,
                                                                 apiKey: key,
                                                                 customBaseURL: customBaseURL,
                                                                 customModel: customModel)
                await MainActor.run {
                    insertTaskTree(nodes)
                    isBusy = false
                    resultMessage = "已为「\(goal.name)」生成 \(nodes.count) 个任务"
                }
            } catch {
                await MainActor.run {
                    isBusy = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

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