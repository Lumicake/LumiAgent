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
                    appState.showingNewAgent = true
                } label: {
                    Label("New Agent", systemImage: "plus")
                }
                .help("Create a new agent")

                Divider()

                Button {
                    Task {
                        await executeCurrentAgent()
                    }
                } label: {
                    Label("Execute", systemImage: "play.fill")
                }
                .disabled(appState.selectedAgentId == nil || executionEngine.isExecuting)
                .help("Execute selected agent")

                Button {
                    Task {
                        await executionEngine.stop()
                    }
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
            case .history:
                ExecutionHistoryView()
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
            case .history:
                if executionEngine.currentSession != nil {
                    AgentExecutionView()
                } else {
                    EmptyDetailView(message: "No active session")
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

// MARK: - Placeholder Views

struct ExecutionHistoryView: View {
    var body: some View {
        List {
            Text("Execution history coming soon...")
        }
        .navigationTitle("History")
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
    @State private var model: String = "llama3"
    @FocusState private var focusedField: Field?

    enum Field {
        case name
        case model
    }

    var body: some View {
        Form {
            Section("Agent Details") {
                TextField("Name", text: $name)
                    .focused($focusedField, equals: .name)

                Picker("Provider", selection: $provider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .onChange(of: provider) {
                    // Update default model when provider changes
                    model = AppConfig.defaultModels[provider] ?? "default"
                }

                TextField("Model", text: $model)
                    .focused($focusedField, equals: .model)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
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
        .frame(width: 500, height: 300)
        .onAppear {
            // Auto-focus name field
            focusedField = .name
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
