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

    /// Apply an agent's self-modification request. Returns a human-readable result string.
    func applySelfUpdate(_ args: [String: String], agentId: UUID) -> String {
        guard let idx = agents.firstIndex(where: { $0.id == agentId }) else {
            return "Error: agent not found."
        }
        var updated = agents[idx]
        var changes: [String] = []

        if let name = args["name"], !name.isEmpty {
            updated.name = name
            changes.append("name → \"\(name)\"")
        }
        if let prompt = args["system_prompt"] {
            updated.configuration.systemPrompt = prompt.isEmpty ? nil : prompt
            changes.append("system prompt updated")
        }
        if let model = args["model"], !model.isEmpty {
            updated.configuration.model = model
            changes.append("model → \(model)")
        }
        if let tempStr = args["temperature"], let temp = Double(tempStr) {
            updated.configuration.temperature = max(0, min(2, temp))
            changes.append("temperature → \(temp)")
        }

        guard !changes.isEmpty else { return "No changes requested." }
        updated.updatedAt = Date()
        updateAgent(updated)
        return "Configuration updated: \(changes.joined(separator: ", "))."
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

    func sendMessage(_ text: String, in conversationId: UUID, agentMode: Bool = false) {
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
                await streamResponse(from: agent, in: conversationId, history: history, agentMode: agentMode)
            }
        }
    }

    private func streamResponse(from agent: Agent, in conversationId: UUID, history: [SpaceMessage], agentMode: Bool = false) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }

        let placeholderId = UUID()
        conversations[index].messages.append(SpaceMessage(
            id: placeholderId, role: .agent, content: "",
            agentId: agent.id, isStreaming: true
        ))

        // Build AI message history.
        // In a group chat, other agents' messages are injected as user-role turns
        // prefixed with their name so this agent knows who said what.
        let convParticipants = agents.filter { conversations[index].participantIds.contains($0.id) }
        let isGroup = convParticipants.count > 1
        var aiMessages: [AIMessage] = history.compactMap { msg in
            if msg.role == .user {
                return AIMessage(role: .user, content: msg.content)
            } else if let senderId = msg.agentId {
                if senderId == agent.id {
                    // Own previous message → assistant role
                    return AIMessage(role: .assistant, content: msg.content)
                } else if isGroup {
                    // Another agent in the group → inject as user turn with name prefix
                    let senderName = agents.first { $0.id == senderId }?.name ?? "Agent"
                    return AIMessage(role: .user, content: "[\(senderName)]: \(msg.content)")
                }
            }
            return nil
        }

        let repo = AIProviderRepository()
        // Always include update_self so any agent can modify itself on request
        var tools = ToolRegistry.shared.getToolsForAI(enabledNames: agent.configuration.enabledTools)
        if !tools.contains(where: { $0.name == "update_self" }),
           let selfTool = ToolRegistry.shared.getTool(named: "update_self") {
            tools.append(selfTool.toAITool())
        }

        // Inject screen control tools when Agent Mode is active
        if agentMode {
            let screenToolNames = [
                "get_screen_info", "move_mouse", "click_mouse", "scroll_mouse",
                "type_text", "press_key", "run_applescript", "take_screenshot"
            ]
            for name in screenToolNames {
                if !tools.contains(where: { $0.name == name }),
                   let t = ToolRegistry.shared.getTool(named: name) {
                    tools.append(t.toAITool())
                }
            }
        }

        // In a group chat, prepend context so each agent knows who else is present
        let effectiveSystemPrompt: String? = {
            var parts: [String] = []
            if agentMode {
                parts.append("""
                You are in Agent Mode with direct control over the user's screen on macOS. \
                You can move the mouse, click, type text, press keys, scroll, run AppleScript, and take screenshots. \
                Screen coordinates use a top-left origin: (0, 0) is the top-left corner. \
                Always call get_screen_info first, then take_screenshot to understand what's on screen before taking action. \
                Work step by step and describe what you're doing as you go. \
                Use run_applescript for complex UI interactions — it supports System Events accessibility APIs.
                """)
            }
            if isGroup {
                let others = convParticipants.filter { $0.id != agent.id }.map { $0.name }
                if !others.isEmpty {
                    parts.append("You are \(agent.name). You are in a group chat with: \(others.joined(separator: ", ")). Their messages appear prefixed with [Name]:.")
                }
            }
            if let base = agent.configuration.systemPrompt, !base.isEmpty { parts.append(base) }
            return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
        }()

        func updatePlaceholder(_ text: String) {
            if let ci = conversations.firstIndex(where: { $0.id == conversationId }),
               let mi = conversations[ci].messages.firstIndex(where: { $0.id == placeholderId }) {
                conversations[ci].messages[mi].content = text
            }
        }

        do {
            if tools.isEmpty {
                // No tools — stream normally
                let stream = try await repo.sendMessageStream(
                    provider: agent.configuration.provider,
                    model: agent.configuration.model,
                    messages: aiMessages,
                    systemPrompt: effectiveSystemPrompt,
                    temperature: agent.configuration.temperature,
                    maxTokens: agent.configuration.maxTokens
                )
                var accumulated = ""
                for try await chunk in stream {
                    if let content = chunk.content, !content.isEmpty {
                        accumulated += content
                        updatePlaceholder(accumulated)
                    }
                }
            } else {
                // Has tools — run a non-streaming tool execution loop
                var iteration = 0
                var finalContent = ""
                while iteration < 10 {
                    iteration += 1
                    let response = try await repo.sendMessage(
                        provider: agent.configuration.provider,
                        model: agent.configuration.model,
                        messages: aiMessages,
                        systemPrompt: effectiveSystemPrompt,
                        tools: tools,
                        temperature: agent.configuration.temperature,
                        maxTokens: agent.configuration.maxTokens
                    )

                    aiMessages.append(AIMessage(
                        role: .assistant,
                        content: response.content ?? "",
                        toolCalls: response.toolCalls
                    ))

                    if let content = response.content, !content.isEmpty {
                        finalContent = content
                        updatePlaceholder(content)
                    }

                    guard let toolCalls = response.toolCalls, !toolCalls.isEmpty else { break }

                    // Show which tools are running
                    let names = toolCalls.map { $0.name }.joined(separator: ", ")
                    updatePlaceholder("Running: \(names)…")

                    for toolCall in toolCalls {
                        let result: String
                        if toolCall.name == "update_self" {
                            result = applySelfUpdate(toolCall.arguments, agentId: agent.id)
                        } else if let tool = ToolRegistry.shared.getTool(named: toolCall.name) {
                            do { result = try await tool.handler(toolCall.arguments) }
                            catch { result = "Error: \(error.localizedDescription)" }
                        } else {
                            result = "Tool not found: \(toolCall.name)"
                        }
                        aiMessages.append(AIMessage(role: .tool, content: result, toolCallId: toolCall.id))
                    }
                }
                if finalContent.isEmpty { updatePlaceholder("(no response)") }
            }
        } catch {
            updatePlaceholder("Error: \(error.localizedDescription)")
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
