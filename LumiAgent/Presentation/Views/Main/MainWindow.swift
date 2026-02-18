//
//  MainWindow.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//
//  Main window with three-column navigation
//

import SwiftUI

// MARK: - Main Window

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @StateObject var executionEngine = AgentExecutionEngine()
    @StateObject var approvalFlow = ApprovalFlow()

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView()
                .frame(minWidth: 200)
        } content: {
            // Content (list view)
            ContentListView()
                .frame(minWidth: 300)
        } detail: {
            // Detail view
            DetailView()
                .frame(minWidth: 400)
        }
        .navigationTitle("Lumi Agent")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await executeCurrentAgent() }
                } label: {
                    Label("Execute", systemImage: "play.fill")
                }
                .disabled(appState.selectedAgentId == nil || executionEngine.isExecuting)
                .help("Execute selected agent")

                Button {
                    Task { await executionEngine.stop() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!executionEngine.isExecuting)
                .help("Stop execution")

                Divider()

                Button {
                    appState.showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .help("Open settings")
            }
        }
        .sheet(isPresented: $appState.showingNewAgent) {
            NewAgentView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $appState.showingSettings) {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 600, minHeight: 500)
        }
        .environmentObject(executionEngine)
        .environmentObject(approvalFlow)
        .focusedSceneValue(\.executionEngine, executionEngine)
        // Show / hide the floating screen-control HUD based on agent state
        .onChange(of: appState.isAgentControllingScreen) { _, isControlling in
            if isControlling {
                ScreenControlOverlayController.shared.show {
                    appState.stopAgentControl()
                }
            } else {
                ScreenControlOverlayController.shared.hide()
            }
        }
    }

    func executeCurrentAgent() async {
        guard let agentId = appState.selectedAgentId,
              let agent = appState.agents.first(where: { $0.id == agentId }) else {
            return
        }

        // TODO: Get user prompt from UI
        let userPrompt = "Hello, please help me with a task"

        do {
            try await executionEngine.execute(agent: agent, userPrompt: userPrompt)
        } catch {
            print("Execution error: \(error)")
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(SidebarItem.allCases, selection: $appState.selectedSidebarItem) { item in
            Label(item.rawValue, systemImage: item.icon)
                .tag(item)
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Content List View

struct ContentListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.selectedSidebarItem {
            case .agents:
                AgentListView()
            case .agentSpace:
                AgentSpaceView()
            case .history:
                ToolHistoryListView()
            case .queue:
                ApprovalQueueListView()
            case .audit:
                AuditLogListView()
            case .settings:
                Text("Settings")
            }
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var executionEngine: AgentExecutionEngine

    var body: some View {
        Group {
            switch appState.selectedSidebarItem {
            case .agents:
                if let agentId = appState.selectedAgentId,
                   let agent = appState.agents.first(where: { $0.id == agentId }) {
                    AgentDetailView(agent: agent)
                } else {
                    EmptyDetailView(message: "Select an agent")
                }
            case .agentSpace:
                if let convId = appState.selectedConversationId {
                    ChatView(conversationId: convId)
                } else {
                    EmptyDetailView(message: "Select or start a conversation")
                }
            case .history:
                if let agentId = appState.selectedHistoryAgentId {
                    ToolHistoryDetailView(agentId: agentId)
                } else {
                    EmptyDetailView(message: "Select an agent to view tool history")
                }
            case .queue:
                ApprovalDetailView()
            case .audit:
                AuditLogDetailView()
            case .settings:
                EmptyDetailView(message: "Settings")
            }
        }
    }
}

// MARK: - Empty Detail View

struct EmptyDetailView: View {
    let message: String

    var body: some View {
        VStack {
            Image(systemName: "sidebar.right")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tool History List View

private struct AgentHistoryEntry: Identifiable {
    let id: UUID      // agentId
    let agent: Agent?
    let name: String
    let records: [ToolCallRecord]
}

struct ToolHistoryListView: View {
    @EnvironmentObject var appState: AppState

    /// Agents that have at least one tool call, sorted by most recent call
    private var activeAgents: [AgentHistoryEntry] {
        let grouped = Dictionary(grouping: appState.toolCallHistory, by: \.agentId)
        return grouped
            .map { (agentId, records) in
                AgentHistoryEntry(
                    id: agentId,
                    agent: appState.agents.first { $0.id == agentId },
                    name: records.first?.agentName ?? "Unknown Agent",
                    records: records
                )
            }
            .sorted { ($0.records.first?.timestamp ?? .distantPast) > ($1.records.first?.timestamp ?? .distantPast) }
    }

    var body: some View {
        if appState.toolCallHistory.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No tool calls yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Tool calls made by agents will appear here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $appState.selectedHistoryAgentId) {
                ForEach(activeAgents) { entry in
                    AgentHistoryRow(entry: entry)
                        .tag(entry.id)
                }
            }
            .navigationTitle("History")
        }
    }
}

private struct AgentHistoryRow: View {
    let entry: AgentHistoryEntry

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(entry.agent?.avatarColor ?? Color.gray)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(entry.name.prefix(1))
                        .font(.caption).fontWeight(.bold).foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.callout).fontWeight(.medium)
                if let latest = entry.records.first {
                    Text(latest.toolName).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.records.count)")
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                if let latest = entry.records.first {
                    Text(latest.timestamp, style: .relative)
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Tool History Detail View

struct ToolHistoryDetailView: View {
    let agentId: UUID
    @EnvironmentObject var appState: AppState

    private var agent: Agent? {
        appState.agents.first { $0.id == agentId }
    }

    private var records: [ToolCallRecord] {
        appState.toolCallHistory.filter { $0.agentId == agentId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(agent?.avatarColor ?? .gray)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text((records.first?.agentName ?? "?").prefix(1))
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(records.first?.agentName ?? "Agent")
                        .font(.headline)
                    Text("\(records.count) tool call\(records.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    appState.toolCallHistory.removeAll { $0.agentId == agentId }
                    appState.selectedHistoryAgentId = nil
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(records) { record in
                        ToolCallRow(record: record)
                        Divider().padding(.leading, 52)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Tool Call Row

struct ToolCallRow: View {
    let record: ToolCallRecord
    @State private var expanded = false

    private var toolIcon: String {
        switch record.toolName {
        case let n where n.contains("file") || n.contains("read") || n.contains("write")
                      || n.contains("directory") || n.contains("delete") || n.contains("copy")
                      || n.contains("move") || n.contains("append"): return "doc.fill"
        case let n where n.contains("command") || n.contains("execute"): return "terminal.fill"
        case let n where n.contains("search") || n.contains("web"): return "magnifyingglass"
        case let n where n.contains("mouse") || n.contains("click") || n.contains("scroll")
                      || n.contains("type") || n.contains("key") || n.contains("screen")
                      || n.contains("applescript"): return "cursorarrow.motionlines"
        case let n where n.contains("git"): return "arrow.triangle.branch"
        case let n where n.contains("http") || n.contains("url") || n.contains("fetch"): return "network"
        case let n where n.contains("screenshot"): return "camera.fill"
        case let n where n.contains("clipboard"): return "clipboard.fill"
        case let n where n.contains("memory"): return "memorychip"
        case let n where n.contains("python") || n.contains("node"): return "chevron.left.forwardslash.chevron.right"
        case "update_self": return "person.crop.circle.badge.checkmark"
        default: return "wrench.fill"
        }
    }

    private var argsSummary: String {
        record.arguments
            .sorted { $0.key < $1.key }
            .prefix(2)
            .map { "\($0.key): \($0.value.prefix(40))" }
            .joined(separator: "  ·  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    // Tool icon
                    ZStack {
                        Circle()
                            .fill(record.success ? Color.accentColor.opacity(0.12) : Color.red.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: toolIcon)
                            .font(.caption)
                            .foregroundStyle(record.success ? Color.accentColor : Color.red)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(record.toolName)
                                .font(.callout)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(record.success ? .green : .red)
                            Text(record.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if !argsSummary.isEmpty {
                            Text(argsSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !record.arguments.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arguments")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            ForEach(record.arguments.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(k)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 100, alignment: .leading)
                                    Text(v)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Result")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(record.result)
                            .font(.caption.monospaced())
                            .foregroundStyle(record.success ? Color.primary : Color.red)
                            .textSelection(.enabled)
                            .lineLimit(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.05))
            }
        }
    }
}

struct ApprovalQueueListView: View {
    @EnvironmentObject var approvalFlow: ApprovalFlow

    var body: some View {
        List(approvalFlow.pendingRequests) { request in
            VStack(alignment: .leading) {
                Text(request.toolCall.name)
                    .font(.headline)
                Text(request.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Approval Queue")
    }
}

struct ApprovalDetailView: View {
    @EnvironmentObject var approvalFlow: ApprovalFlow

    var body: some View {
        if let request = approvalFlow.currentRequest {
            VStack(alignment: .leading, spacing: 16) {
                Text("Approval Required")
                    .font(.title)

                Text(request.toolCall.name)
                    .font(.headline)

                Text(request.reasoning)

                HStack {
                    Button("Deny") {
                        Task {
                            try? await approvalFlow.denyCurrent()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Approve") {
                        Task {
                            try? await approvalFlow.approveCurrent()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        } else {
            EmptyDetailView(message: "No pending approvals")
        }
    }
}

struct AuditLogListView: View {
    var body: some View {
        List {
            Text("Audit logs coming soon...")
        }
        .navigationTitle("Audit Logs")
    }
}

struct AuditLogDetailView: View {
    var body: some View {
        EmptyDetailView(message: "Select an audit log entry")
    }
}

// MARK: - New Agent View

struct NewAgentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var provider: AIProvider = .ollama
    @State private var model: String = AppConfig.defaultModels[.ollama] ?? "llama3.2:latest"
    @State private var availableModels: [String] = AIProvider.ollama.defaultModels
    @State private var loadingModels = false
    @FocusState private var focusedField: Field?

    enum Field { case name }

    var body: some View {
        Form {
            Section("Agent Details") {
                TextField("Name", text: $name)
                    .focused($focusedField, equals: .name)

                Picker("Provider", selection: $provider) {
                    ForEach(AIProvider.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .onChange(of: provider) {
                    model = AppConfig.defaultModels[provider] ?? ""
                    fetchModels()
                }

                HStack(spacing: 8) {
                    if availableModels.isEmpty {
                        TextField("Model", text: $model)
                    } else {
                        Picker("Model", selection: $model) {
                            ForEach(availableModels, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                    }
                    if loadingModels {
                        ProgressView().scaleEffect(0.7)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Create") {
                    createAgent()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .padding()
        .frame(width: 500, height: 280)
        .onAppear {
            focusedField = .name
            fetchModels()
        }
    }

    private func fetchModels() {
        availableModels = provider.defaultModels
        guard provider == .ollama else { return }
        loadingModels = true
        Task {
            let repo = AIProviderRepository()
            if let live = try? await repo.getAvailableModels(provider: .ollama), !live.isEmpty {
                await MainActor.run {
                    availableModels = live
                    if !live.contains(model) { model = live.first ?? model }
                }
            }
            await MainActor.run { loadingModels = false }
        }
    }

    private func createAgent() {
        let agent = Agent(
            name: name,
            configuration: AgentConfiguration(
                provider: provider,
                model: model
            )
        )
        appState.agents.append(agent)

        // Save to database
        Task {
            let repo = AgentRepository()
            try? await repo.create(agent)
        }
    }
}
