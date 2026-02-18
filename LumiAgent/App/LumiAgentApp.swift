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
            LumiAgentCommands(
                selectedSidebarItem: $appState.selectedSidebarItem,
                appState: appState
            )
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Screen Capture Helper

/// Captures the full screen and returns JPEG data scaled to maxWidth pixels wide.
/// Runs synchronously — call from a background thread / Task.detached.
private func captureScreenForVision(maxWidth: CGFloat = 1440) -> Data? {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi_vision_\(UUID().uuidString).png")
    defer { try? FileManager.default.removeItem(at: tmpURL) }

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    proc.arguments = ["-x", tmpURL.path]   // -x = no shutter sound
    guard (try? proc.run()) != nil else { return nil }
    proc.waitUntilExit()
    guard proc.terminationStatus == 0 else { return nil }

    // Load via CGImageSource (thread-safe)
    guard let src = CGImageSourceCreateWithURL(tmpURL as CFURL, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil)
    else { return nil }

    // Scale down preserving aspect ratio
    let origW = CGFloat(cg.width), origH = CGFloat(cg.height)
    let scale = min(1.0, maxWidth / origW)
    let tw = Int(origW * scale), th = Int(origH * scale)

    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: tw, height: th,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: tw, height: th))
    guard let scaled = ctx.makeImage() else { return nil }

    let rep = NSBitmapImageRep(cgImage: scaled)
    return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
}

/// Tool names that visually change the screen — a screenshot is worthwhile after these.
private let screenControlToolNames: Set<String> = [
    "open_application", "click_mouse", "scroll_mouse",
    "type_text", "press_key", "run_applescript", "take_screenshot"
]

// MARK: - App State

// MARK: - Tool Call Record

struct ToolCallRecord: Identifiable {
    let id: UUID
    let agentId: UUID
    let agentName: String
    let toolName: String
    let arguments: [String: String]
    let result: String
    let timestamp: Date
    let success: Bool

    init(agentId: UUID, agentName: String, toolName: String,
         arguments: [String: String], result: String, success: Bool) {
        self.id = UUID()
        self.agentId = agentId
        self.agentName = agentName
        self.toolName = toolName
        self.arguments = arguments
        self.result = result
        self.timestamp = Date()
        self.success = success
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

    // MARK: - Tool Call History
    @Published var toolCallHistory: [ToolCallRecord] = []
    @Published var selectedHistoryAgentId: UUID?

    // MARK: - Screen Control State
    /// True while the agent is actively running tools in Agent Mode.
    @Published var isAgentControllingScreen = false
    /// Counts concurrent screen-control agents so the flag clears only when all finish.
    private var screenControlCount = 0
    /// Stored Task handles so we can cancel them from the Stop button.
    private var screenControlTasks: [Task<Void, Never>] = []

    private let conversationsKey = "lumiagent.conversations"

    init() {
        _ = DatabaseManager.shared
        loadAgents()
        loadConversations()
        // Register ⌘L global hotkey after init completes
        DispatchQueue.main.async { [weak self] in
            self?.setupGlobalHotkey()
        }
    }

    // MARK: - Global Hotkey

    private func setupGlobalHotkey() {
        // Use Carbon RegisterEventHotKey so the shortcut is truly intercepted
        // globally — it never reaches the frontmost app.
        // Default: ⌥⌘L (Option + Command + L). Override by calling
        // GlobalHotkeyManager.shared.register(keyCode:modifiers:) in AppDelegate.
        GlobalHotkeyManager.shared.onActivate = { [weak self] in
            self?.toggleCommandPalette()
        }
        GlobalHotkeyManager.shared.register()
    }

    func toggleCommandPalette() {
        CommandPaletteController.shared.toggle(agents: agents) { [weak self] text, agentId in
            self?.sendCommandPaletteMessage(text: text, agentId: agentId)
        }
    }

    /// Routes a command-palette submission into the normal agent-mode send path.
    func sendCommandPaletteMessage(text: String, agentId: UUID?) {
        let targetId = agentId ?? agents.first?.id
        guard let targetId, agents.contains(where: { $0.id == targetId }) else { return }

        // Find or create a DM with the target agent, then send in agent mode
        let conv = createDM(agentId: targetId)
        sendMessage(text, in: conv.id, agentMode: true)

        // Bring our window to front so the user sees the response
        NSApp.activate(ignoringOtherApps: true)
    }

    func recordToolCall(agentId: UUID, agentName: String, toolName: String,
                        arguments: [String: String], result: String) {
        let success = !result.hasPrefix("Error:") && !result.hasPrefix("Tool not found:")
        toolCallHistory.insert(
            ToolCallRecord(agentId: agentId, agentName: agentName, toolName: toolName,
                           arguments: arguments, result: result, success: success),
            at: 0
        )
    }

    /// Called by the Stop button on the floating overlay.
    func stopAgentControl() {
        screenControlTasks.forEach { $0.cancel() }
        screenControlTasks.removeAll()
        screenControlCount = 0
        isAgentControllingScreen = false
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
            let task = Task {
                await streamResponse(from: agent, in: conversationId, history: history, agentMode: agentMode)
            }
            if agentMode {
                screenControlTasks.append(task)
            }
        }
    }

    private func streamResponse(from agent: Agent, in conversationId: UUID, history: [SpaceMessage], agentMode: Bool = false) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }

        // Only raise the screen-control flag when a screen tool is actually called,
        // not at the start of every agent-mode response.
        var didRaiseScreenControl = false
        defer {
            if didRaiseScreenControl {
                screenControlCount = max(0, screenControlCount - 1)
                if screenControlCount == 0 {
                    isAgentControllingScreen = false
                    screenControlTasks.removeAll { $0.isCancelled }
                }
            }
        }

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
        // In Agent Mode, give the agent access to every registered tool so it
        // can complete multi-step tasks (search → reason → write, etc.) without
        // the user having to pre-enable individual tools.
        // Outside Agent Mode, respect the agent's explicit enabledTools list.
        var tools: [AITool]
        if agentMode {
            tools = ToolRegistry.shared.getToolsForAI() // all tools, no filter
        } else {
            tools = ToolRegistry.shared.getToolsForAI(enabledNames: agent.configuration.enabledTools)
        }
        if !tools.contains(where: { $0.name == "update_self" }),
           let selfTool = ToolRegistry.shared.getTool(named: "update_self") {
            tools.append(selfTool.toAITool())
        }

        // In a group chat, prepend context so each agent knows who else is present
        let effectiveSystemPrompt: String? = {
            var parts: [String] = []
            if agentMode {
                parts.append("""
                You are in Agent Mode. You have FULL autonomous control of the user's Mac — file system, web, shell, apps, and screen.

                ═══ MULTI-STEP TASK EXECUTION ═══
                For any task that requires multiple steps (research → reason → write, open app → interact → verify, etc.):
                  1. PLAN silently: identify every step needed to fully complete the task.
                  2. EXECUTE each step immediately using the appropriate tool — do NOT narrate future steps, just do them.
                  3. CHAIN results: use the output of one tool as input to the next tool call.
                  4. ONLY give a final text response when EVERY step is 100% complete.
                  5. NEVER stop mid-task and ask the user to continue or do anything manually.

                EXAMPLE — "search for X, then write a report on the Desktop":
                  Step 1 → call web_search("X")
                  Step 2 → call web_search again for more detail if needed
                  Step 3 → call write_file(path: "/Users/<user>/Desktop/report.txt", content: <full report>)
                  Step 4 → respond: "Done — report saved to your Desktop."

                EXAMPLE — "open Safari and go to apple.com":
                  Step 1 → call open_application("Safari")
                  Step 2 → call run_applescript to navigate to the URL
                  Step 3 → call take_screenshot to verify
                  Step 4 → respond with result.

                ═══ TOOL SELECTION GUIDE ═══
                • Research / web data   → web_search, fetch_url
                • Files on disk         → write_file, read_file, list_directory, create_directory
                • Shell / automation    → execute_command, run_applescript
                • Open apps / URLs      → open_application, open_url
                • Screen interaction    → get_screen_info, click_mouse, type_text, press_key, take_screenshot
                • Memory across turns   → memory_save, memory_read

                ═══ SCREEN CONTROL ═══
                • Prefer run_applescript for in-app UI (more reliable than raw mouse clicks).
                • AppleScript pattern:
                    tell application "AppName" to activate
                    delay 0.8
                    tell application "System Events"
                        tell process "AppName"
                            set value of text field 1 of window 1 to "text"
                            key code 36  -- Return
                        end tell
                    end tell
                • Fallback: take_screenshot → read coordinates → click_mouse / type_text.
                • Screen origin is top-left (0,0). Call get_screen_info to get dimensions.

                ═══ ABSOLUTE RULES ═══
                1. NEVER tell the user to "manually" do anything.
                2. NEVER stop after one tool call and ask what to do next — keep executing until the full task is done.
                3. NEVER leave a task half-finished. If a step fails, try an alternative approach.
                4. Desktop path: use execute_command("echo $HOME") to get the user's home, then write to $HOME/Desktop/.
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
                let maxIterations = agentMode ? 30 : 10
                var finalContent = ""
                while iteration < maxIterations {
                    iteration += 1

                    // Respect cancellation (Stop button)
                    if Task.isCancelled {
                        updatePlaceholder(finalContent.isEmpty ? "Stopped." : finalContent)
                        break
                    }

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

                    // Track whether this batch touched the screen
                    var touchedScreen = false

                    for toolCall in toolCalls {
                        if Task.isCancelled { break }

                        let result: String
                        if toolCall.name == "update_self" {
                            result = applySelfUpdate(toolCall.arguments, agentId: agent.id)
                        } else if let tool = ToolRegistry.shared.getTool(named: toolCall.name) {
                            do { result = try await tool.handler(toolCall.arguments) }
                            catch { result = "Error: \(error.localizedDescription)" }
                        } else {
                            result = "Tool not found: \(toolCall.name)"
                        }
                        recordToolCall(agentId: agent.id, agentName: agent.name,
                                       toolName: toolCall.name, arguments: toolCall.arguments,
                                       result: result)
                        aiMessages.append(AIMessage(role: .tool, content: result, toolCallId: toolCall.id))

                        if screenControlToolNames.contains(toolCall.name) {
                            touchedScreen = true
                            // Raise the overlay the first time a screen tool fires
                            if agentMode && !didRaiseScreenControl {
                                didRaiseScreenControl = true
                                screenControlCount += 1
                                isAgentControllingScreen = true
                            }
                        }
                    }

                    // ── Vision feedback loop ──────────────────────────────
                    // After any batch that changed the screen, capture a
                    // screenshot and inject it as the next user vision message
                    // so the AI can see exactly what's on screen and decide
                    // the next action precisely.
                    if agentMode && touchedScreen && !Task.isCancelled {
                        updatePlaceholder((finalContent.isEmpty ? "" : finalContent + "\n\n") +
                                          "📸 Capturing screen to see current state…")

                        // Give the UI time to settle before capturing
                        try? await Task.sleep(nanoseconds: 900_000_000) // 0.9 s

                        // Capture off the main actor so Process doesn't block the run loop
                        let screenshotData = await Task.detached(priority: .userInitiated) {
                            captureScreenForVision(maxWidth: 1440)
                        }.value

                        if let data = screenshotData {
                            aiMessages.append(AIMessage(
                                role: .user,
                                content: "Here is the current screen state after your last actions. " +
                                         "Look at the screenshot carefully: identify every visible UI element, " +
                                         "button, text field, and icon with its approximate screen position. " +
                                         "Then continue the task — decide what to click, type, or do next, " +
                                         "and call the appropriate tool(s).",
                                imageData: data
                            ))
                        }
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
