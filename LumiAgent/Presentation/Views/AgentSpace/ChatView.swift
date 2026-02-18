//
//  ChatView.swift
//  LumiAgent
//
//  Chat interface with @mention routing and streaming responses.
//

import SwiftUI

// MARK: - Chat View

struct ChatView: View {
    let conversationId: UUID
    @EnvironmentObject var appState: AppState
    @State private var inputText = ""

    var conversation: Conversation? {
        appState.conversations.first { $0.id == conversationId }
    }

    var participants: [Agent] {
        guard let conv = conversation else { return [] }
        return appState.agents.filter { conv.participantIds.contains($0.id) }
    }

    var body: some View {
        Group {
            if let conv = conversation {
                VStack(spacing: 0) {
                    chatHeader(conv: conv)
                    Divider()
                    messagesArea(conv: conv)
                    Divider()
                    MessageInputView(
                        text: $inputText,
                        agents: participants,
                        onSend: sendMessage
                    )
                }
            } else {
                EmptyDetailView(message: "Conversation not found")
            }
        }
        .navigationTitle("")
    }

    // MARK: - Header

    @ViewBuilder
    private func chatHeader(conv: Conversation) -> some View {
        HStack(spacing: 12) {
            participantAvatarStack
            VStack(alignment: .leading, spacing: 2) {
                Text(conv.displayTitle(agents: appState.agents))
                    .font(.headline)
                if conv.isGroup {
                    Text("\(participants.count) participants")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let agent = participants.first {
                    Text("\(agent.configuration.provider.rawValue) · \(agent.configuration.model)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var participantAvatarStack: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(participants.prefix(3).enumerated()), id: \.element.id) { index, agent in
                Circle()
                    .fill(agent.avatarColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(agent.name.prefix(1))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .overlay(Circle().stroke(Color(.windowBackgroundColor), lineWidth: 1.5))
                    .offset(x: CGFloat(index) * 20)
            }
        }
        .frame(width: CGFloat(min(participants.count, 3)) * 20 + 12, height: 32)
    }

    // MARK: - Messages

    @ViewBuilder
    private func messagesArea(conv: Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if conv.messages.isEmpty {
                        emptyConversationHint(conv: conv)
                    } else {
                        ForEach(conv.messages) { msg in
                            MessageBubble(
                                message: msg,
                                agent: agentFor(msg),
                                allAgents: appState.agents
                            )
                            .id(msg.id)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: conv.messages.count) {
                scrollToBottom(conv: conv, proxy: proxy)
            }
            .onAppear {
                scrollToBottom(conv: conv, proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private func emptyConversationHint(conv: Conversation) -> some View {
        VStack(spacing: 12) {
            participantAvatarStack
            Text("Start a conversation with \(conv.displayTitle(agents: appState.agents))")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if conv.isGroup {
                Text("Use @AgentName to direct a message to a specific participant.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        appState.sendMessage(text, in: conversationId)
    }

    private func agentFor(_ message: SpaceMessage) -> Agent? {
        guard let id = message.agentId else { return nil }
        return appState.agents.first { $0.id == id }
    }

    private func scrollToBottom(conv: Conversation, proxy: ScrollViewProxy) {
        guard let last = conv.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: SpaceMessage
    let agent: Agent?
    let allAgents: [Agent]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .agent {
                agentAvatar
                    .padding(.top, 18) // align with text below label

                VStack(alignment: .leading, spacing: 3) {
                    Text(agent?.name ?? "Agent")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    bubbleContent
                }
                Spacer(minLength: 80)
            } else {
                Spacer(minLength: 80)
                bubbleContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var agentAvatar: some View {
        let color = agent?.avatarColor ?? Color.gray
        Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(
                Text((agent?.name ?? "?").prefix(1))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let isUser = message.role == .user

        Group {
            if message.isStreaming && message.content.isEmpty {
                TypingIndicator()
            } else {
                MentionText(text: message.content, agents: allAgents)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUser ? Color.accentColor : Color.secondary.opacity(0.12))
                    .foregroundColor(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

// MARK: - Mention Text

struct MentionText: View {
    let text: String
    let agents: [Agent]

    var body: some View {
        Text(attributedText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedText: AttributedString {
        var result = AttributedString(text)
        for agent in agents {
            let mention = "@\(agent.name)"
            var searchStart = result.startIndex
            while searchStart < result.endIndex,
                  let range = result[searchStart...].range(of: mention) {
                result[range].foregroundColor = .accentColor
                result[range].font = Font.body.weight(.semibold)
                searchStart = range.upperBound
            }
        }
        return result
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase ? 1.0 : 0.5)
                    .opacity(phase ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { phase = true }
    }
}

// MARK: - Message Input View

struct MessageInputView: View {
    @Binding var text: String
    let agents: [Agent]
    let onSend: () -> Void

    @State private var mentionQuery: String? = nil

    private var filteredAgents: [Agent] {
        guard let query = mentionQuery else { return [] }
        if query.isEmpty { return agents }
        return agents.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // @mention autocomplete popup
            if !filteredAgents.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredAgents) { agent in
                        Button {
                            insertMention(agent)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(agent.avatarColor)
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Text(agent.name.prefix(1))
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("@\(agent.name)")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                    Text(agent.configuration.model)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if agent.id != filteredAgents.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(.bar)

                Divider()
            }

            // Input row
            HStack(alignment: .bottom, spacing: 10) {
                TextEditor(text: $text)
                    .frame(minHeight: 36, maxHeight: 100)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .onChange(of: text) {
                        updateMentionState()
                    }
                    .onKeyPress(.return) {
                        performSend()
                        return .handled
                    }

                Button(action: performSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(canSend ? Color.accentColor : Color.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func performSend() {
        guard canSend else { return }
        mentionQuery = nil
        onSend()
    }

    private func updateMentionState() {
        let parts = text.components(separatedBy: "@")
        if parts.count > 1, let last = parts.last, !last.contains(" "), !last.contains("\n") {
            mentionQuery = last
        } else {
            mentionQuery = nil
        }
    }

    private func insertMention(_ agent: Agent) {
        let parts = text.components(separatedBy: "@")
        guard parts.count > 1 else { return }
        let prefix = parts.dropLast().joined(separator: "@")
        text = prefix + "@\(agent.name) "
        mentionQuery = nil
    }
}
