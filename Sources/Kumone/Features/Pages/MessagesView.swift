import SwiftUI

/// 私信 — 会话列表；接口照搬备用源码 MeloX（`/msg/private/users`）。
struct MessagesView: View {
    @EnvironmentObject private var account: AccountStore

    @State private var loadedAccountID: Int?
    @State private var loadID = UUID()
    @State private var conversations: [PrivateConversation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        let currentUserID = account.authenticatedAccountID
        List {
            if currentUserID == nil || currentUserID != loadedAccountID {
                if account.hasAuthCookie, currentUserID != nil {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    Text(account.hasAuthCookie ? "账号资料尚未就绪" : "登录后才能收发私信")
                        .foregroundStyle(.secondary)
                }
            } else {
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                }
                if isLoading, conversations.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 220)
                } else if conversations.isEmpty {
                    EmptyStateView(icon: "bubble.left.and.bubble.right",
                                   title: "还没有私信",
                                   subtitle: "和好友在网易云里聊过天后，会话会出现在这里。")
                        .frame(minHeight: 260)
                } else {
                    ForEach(conversations) { conversation in
                        if let ownerID = currentUserID,
                           let peer = conversation.peer(currentUserID: ownerID), let uid = peer.userId {
                            NavigationLink(value: Destination.conversation(uid, peer.displayName, ownerID)) {
                                row(conversation, peer: peer)
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { PlayerClearanceSpacer() }
        .navigationTitle("私信")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: currentUserID) { await load(ownerID: currentUserID) }
        .refreshable { await load(ownerID: currentUserID) }
    }

    private func row(_ conversation: PrivateConversation, peer: MessageContact) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: peer.avatarUrl?.resizedImageURL(96))
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(peer.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                Text(PrivateMessagePayload.text(from: conversation.lastMsg))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if let time = conversation.lastMsgTime, time > 0 {
                    Text(Self.timeText(time))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let unread = conversation.newMsgCount, unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent, in: Capsule())
                }
            }
        }
    }

    private func load(ownerID: Int?) async {
        guard !Task.isCancelled, ownerID == account.authenticatedAccountID else { return }
        if loadedAccountID != ownerID { conversations = [] }
        loadedAccountID = ownerID
        errorMessage = nil
        let request = UUID()
        loadID = request
        guard let ownerID, let session = MusicClient.shared.authenticationFingerprint else {
            isLoading = false
            return
        }
        isLoading = true
        defer { if loadID == request { isLoading = false } }
        do {
            let result = try await MusicAPI.privateConversations(binding: session)
            guard loadID == request, account.authenticatedAccountID == ownerID,
                  session == MusicClient.shared.authenticationFingerprint, !Task.isCancelled else { return }
            conversations = result
        } catch {
            guard loadID == request, account.authenticatedAccountID == ownerID,
                  session == MusicClient.shared.authenticationFingerprint, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    static func timeText(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        let sameDay = Calendar.current.isDateInToday(date)
        formatter.dateFormat = sameDay ? "HH:mm" : "M/d"
        return formatter.string(from: date)
    }
}

/// 单个会话：气泡列表 + 底部输入条。
struct ConversationView: View {
    let userID: Int
    let nickname: String
    let ownerID: Int

    @EnvironmentObject private var account: AccountStore

    @State private var historyID = UUID()
    @State private var scrollRequest = 0
    private static let historyEnd = "chat-history-end"
    @State private var messages: [PrivateMessage] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var draftFocused: Bool

    var body: some View {
        let currentAccount = account.authenticatedAccountID
        Group {
            if ownsConversation {
                conversationBody
            } else {
                EmptyStateView(icon: "bubble.left", title: "账号已变更，请返回私信列表")
            }
        }
        .navigationTitle(ownsConversation ? nickname : String(localized: "私信"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: currentAccount) {
            guard !Task.isCancelled, currentAccount == account.authenticatedAccountID else { return }
            resetIfAccountChanged()
            if ownsConversation { await load() }
        }
    }

    private var conversationBody: some View {
        Group {
            if isLoading, messages.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    if #available(iOS 17.0, macOS 14.0, *) {
                        historyScroll(proxy).defaultScrollAnchor(.bottom)
                    } else {
                        historyScroll(proxy).onAppear { scrollToLatest(proxy) }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
    }

    private func historyScroll(_ proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if messages.isEmpty, errorMessage == nil {
                    EmptyStateView(icon: "bubble.left", title: "还没有聊天记录", subtitle: "发第一条消息试试。")
                        .frame(minHeight: 220)
                }
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    bubble(message)
                }
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                }
                Color.clear.frame(height: 0).id(Self.historyEnd)
            }
            .padding(.horizontal, Theme.Layout.contentInset)
            .padding(.vertical, 12)
        }
        .onChange(of: scrollRequest) { _ in scrollToLatest(proxy) }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo(Self.historyEnd, anchor: .bottom) }
    }

    private var ownsConversation: Bool { account.authenticatedAccountID == ownerID }

    private func resetIfAccountChanged() {
        guard !ownsConversation else { return }
        historyID = UUID()
        messages = []
        draft = ""
        draftFocused = false
        isSending = false
        isLoading = true
        errorMessage = nil
    }

    @ViewBuilder
    private func bubble(_ message: PrivateMessage) -> some View {
        let outgoing = message.isOutgoing(currentUserID: ownerID)
        HStack {
            if outgoing { Spacer(minLength: 40) }
            VStack(alignment: outgoing ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(outgoing ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        outgoing ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.primary.opacity(0.07)),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                if let time = message.time, time > 0 {
                    Text(MessagesView.timeText(time))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            if !outgoing { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("发消息…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($draftFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onSubmit { Task { await send() } }
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(canSend ? Theme.accent : Color.secondary.opacity(0.5))
            }
            .disabled(!canSend)
            .accessibilityLabel("发送")
        }
        .padding(.horizontal, Theme.Layout.contentInset)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        ownsConversation && !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load(scrollAfterSend: Bool = false) async {
        guard ownsConversation, !Task.isCancelled,
              let session = MusicClient.shared.authenticationFingerprint else { return }
        let request = UUID()
        historyID = request
        func isCurrent() -> Bool {
            ownsConversation && historyID == request
                && session == MusicClient.shared.authenticationFingerprint && !Task.isCancelled
        }
        do {
            let result = try await MusicAPI.privateHistory(userID: userID, binding: session)
            guard isCurrent() else { return }
            messages = result
            if scrollAfterSend { scrollRequest &+= 1 }
            errorMessage = nil
        } catch {
            guard isCurrent() else { return }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func send() async {
        guard canSend, let session = MusicClient.shared.authenticationFingerprint else { return }
        let submittedDraft = draft
        func isCurrent() -> Bool {
            ownsConversation && session == MusicClient.shared.authenticationFingerprint
        }
        let text = submittedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        defer { if isCurrent() { isSending = false } }
        do {
            try await MusicAPI.sendPrivateText(text, to: userID, binding: session)
        } catch {
            if isCurrent() { errorMessage = error.localizedDescription }
            return
        }
        guard isCurrent() else { return }
        if draft == submittedDraft { draft = "" }
        await load(scrollAfterSend: true)
    }
}
