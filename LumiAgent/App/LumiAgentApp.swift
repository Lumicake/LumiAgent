//
//  LumiAgentApp.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import SwiftUI

@main
struct LumiAgentApp: App {
    // MARK: - Properties

    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // App initialization
        setupBundleIdentifier()
    }

    private func setupBundleIdentifier() {
        // Inject bundle identifier for Swift Package Manager builds
        if Bundle.main.bundleIdentifier == nil || Bundle.main.bundleIdentifier?.isEmpty == true {
            // Set via environment or default
            let bundleID = ProcessInfo.processInfo.environment["PRODUCT_BUNDLE_IDENTIFIER"] ?? "com.lumiagent.app"
            print("⚙️ Setting bundle identifier: \(bundleID)")
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 600)
        }
        .commands {
            LumiAgentCommands(selectedSidebarItem: $appState.selectedSidebarItem)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @Published var selectedSidebarItem: SidebarItem = .agents
    @Published var selectedAgentId: UUID?
    @Published var agents: [Agent] = []
    @Published var showingNewAgent = false
    @Published var showingSettings = false

    // MARK: - Agent Space
    @Published var conversations: [Conversation] = [] {
        didSet { saveConversations() }
    }
    @Published var selectedConversationId: UUID?

    private let conversationsKey = "lumiagent.conversations"

    init() {
        _ = DatabaseManager.shared
        loadAgents()
        loadConversations()
    }

    // MARK: - Agent persistence

    private func loadAgents() {
        Task {
            let repo = AgentRepository()
            do {
                self.agents = try await repo.getAll()
            } catch {
                print("Error loading agents: \(error)")
            }
        }
    }

    func updateAgent(_ agent: Agent) {
        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[index] = agent
        }
        Task {
            let repo = AgentRepository()
            try? await repo.update(agent)
        }
    }

    func deleteAgent(id: UUID) {
        agents.removeAll { $0.id == id }
        if selectedAgentId == id { selectedAgentId = nil }
        Task {
            let repo = AgentRepository()
            try? await repo.delete(id: id)
        }
    }

    // MARK: - Conversation management

    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: conversationsKey),
              let saved = try? JSONDecoder().decode([Conversation].self, from: data) else { return }
        conversations = saved
    }

    private func saveConversations() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        UserDefaults.standard.set(data, forKey: conversationsKey)
    }

    @discardableResult
    func createDM(agentId: UUID) -> Conversation {
        // Reuse existing DM if one exists
        if let existing = conversations.first(where: { !$0.isGroup && $0.participantIds == [agentId] }) {
            selectedConversationId = existing.id
            selectedSidebarItem = .agentSpace
            return existing
        }
        let conv = Conversation(participantIds: [agentId])
        conversations.insert(conv, at: 0)
        selectedConversationId = conv.id
        selectedSidebarItem = .agentSpace
        return conv
    }

    @discardableResult
    func createGroup(agentIds: [UUID], title: String?) -> Conversation {
        let conv = Conversation(title: title, participantIds: agentIds)
        conversations.insert(conv, at: 0)
        selectedConversationId = conv.id
        selectedSidebarItem = .agentSpace
        return conv
    }

    func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }
        if selectedConversationId == id { selectedConversationId = nil }
    }

    // MARK: - Messaging

    func sendMessage(_ text: String, in conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }

        let userMsg = SpaceMessage(role: .user, content: text)
        conversations[index].messages.append(userMsg)
        conversations[index].updatedAt = Date()

        let conv = conversations[index]
        let participants = agents.filter { conv.participantIds.contains($0.id) }

        // Determine targets: @mentioned agents, or all participants if none mentioned
        let mentioned = participants.filter { text.contains("@\($0.name)") }
        let targets = mentioned.isEmpty ? participants : mentioned

        for agent in targets {
            let history = conv.messages.filter { !$0.isStreaming }
            Task {
                await streamResponse(from: agent, in: conversationId, history: history)
            }
        }
    }

    private func streamResponse(from agent: Agent, in conversationId: UUID, history: [SpaceMessage]) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }

        let placeholderId = UUID()
        let placeholder = SpaceMessage(
            id: placeholderId,
            role: .agent,
            content: "",
            agentId: agent.id,
            isStreaming: true
        )
        conversations[index].messages.append(placeholder)

        let aiMessages: [AIMessage] = history.map { msg in
            AIMessage(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content
            )
        }

        let repo = AIProviderRepository()
        do {
            let stream = try await repo.sendMessageStream(
                provider: agent.configuration.provider,
                model: agent.configuration.model,
                messages: aiMessages,
                systemPrompt: agent.configuration.systemPrompt,
                temperature: agent.configuration.temperature,
                maxTokens: agent.configuration.maxTokens
            )

            for try await chunk in stream {
                if let content = chunk.content, !content.isEmpty {
                    if let ci = conversations.firstIndex(where: { $0.id == conversationId }),
                       let mi = conversations[ci].messages.firstIndex(where: { $0.id == placeholderId }) {
                        conversations[ci].messages[mi].content += content
                    }
                }
            }
        } catch {
            // Show error in the message bubble
            if let ci = conversations.firstIndex(where: { $0.id == conversationId }),
               let mi = conversations[ci].messages.firstIndex(where: { $0.id == placeholderId }) {
                conversations[ci].messages[mi].content = "Error: \(error.localizedDescription)"
            }
        }

        // Mark streaming done
        if let ci = conversations.firstIndex(where: { $0.id == conversationId }),
           let mi = conversations[ci].messages.firstIndex(where: { $0.id == placeholderId }) {
            conversations[ci].messages[mi].isStreaming = false
        }

        if let ci = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[ci].updatedAt = Date()
        }
    }
}

// MARK: - Sidebar Item

enum SidebarItem: String, CaseIterable, Identifiable {
    case agents = "Agents"
    case agentSpace = "Agent Space"
    case history = "History"
    case queue = "Approval Queue"
    case audit = "Audit Logs"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .agents: return "cpu"
        case .agentSpace: return "bubble.left.and.bubble.right.fill"
        case .history: return "clock.arrow.circlepath"
        case .queue: return "checkmark.shield"
        case .audit: return "doc.text.magnifyingglass"
        case .settings: return "gear"
        }
    }
}
