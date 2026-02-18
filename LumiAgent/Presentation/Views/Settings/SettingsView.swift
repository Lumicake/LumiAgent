//
//  SettingsView.swift
//  LumiAgent
//

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            APIKeysTab()
                .tabItem { Label("API Keys", systemImage: "key.fill") }

            SecurityTab()
                .tabItem { Label("Security", systemImage: "shield.fill") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
        }
        .frame(width: 560, height: 460)
    }
}

// MARK: - API Keys Tab

private struct APIKeysTab: View {
    @AppStorage("settings.ollamaURL") private var ollamaURL = AppConfig.defaultOllamaURL

    // Input fields
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var geminiKey = ""

    // Saved-flash state
    @State private var savedProvider: AIProvider? = nil

    // Whether a key already exists in keychain
    @State private var hasKey: [AIProvider: Bool] = [:]

    var body: some View {
        Form {
            apiKeySection(
                provider: .openai,
                icon: "brain", color: .green,
                title: "OpenAI",
                placeholder: "sk-…",
                key: $openAIKey
            )

            apiKeySection(
                provider: .anthropic,
                icon: "sparkles", color: .purple,
                title: "Anthropic",
                placeholder: "sk-ant-…",
                key: $anthropicKey
            )

            apiKeySection(
                provider: .gemini,
                icon: "atom", color: .blue,
                title: "Gemini (Google AI)",
                placeholder: "AIza…",
                key: $geminiKey
            )

            // Ollama — URL only, no key
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ollama")
                            .font(.headline)
                        Text("Local server — no API key required")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Server URL") {
                    TextField("http://localhost:11434", text: $ollamaURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                }

                Button("Reset to Default") {
                    ollamaURL = AppConfig.defaultOllamaURL
                }
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { loadKeyStatus() }
    }

    @ViewBuilder
    private func apiKeySection(
        provider: AIProvider,
        icon: String, color: Color,
        title: String,
        placeholder: String,
        key: Binding<String>
    ) -> some View {
        let stored = hasKey[provider] == true
        Section {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(stored ? "API key saved" : "No key stored")
                        .font(.caption)
                        .foregroundStyle(stored ? .green : .secondary)
                }
                Spacer()
                if savedProvider == provider {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                        .transition(.opacity)
                }
            }

            SecureField(stored ? "Enter new key to replace…" : placeholder, text: key)

            Button("Save \(title) Key") {
                save(key.wrappedValue, for: provider)
                key.wrappedValue = ""
                hasKey[provider] = true
                savedProvider = provider
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if savedProvider == provider { savedProvider = nil }
                }
            }
            .disabled(key.wrappedValue.isEmpty)
        }
    }

    private func loadKeyStatus() {
        let repo = AIProviderRepository()
        for provider in [AIProvider.openai, .anthropic, .gemini] {
            hasKey[provider] = (try? repo.getAPIKey(for: provider)).flatMap { $0.isEmpty ? nil : $0 } != nil
        }
    }

    private func save(_ key: String, for provider: AIProvider) {
        let repo = AIProviderRepository()
        try? repo.setAPIKey(key, for: provider)
    }
}

// MARK: - Security Tab

private struct SecurityTab: View {
    @AppStorage("settings.allowSudo") private var allowSudo = false
    @AppStorage("settings.requireApproval") private var requireApproval = true
    @AppStorage("settings.autoApproveThreshold") private var thresholdRaw = RiskLevel.low.rawValue
    @AppStorage("settings.enableAuditLogs") private var enableAuditLogs = true

    private var autoApproveThreshold: Binding<RiskLevel> {
        Binding(
            get: { RiskLevel(rawValue: thresholdRaw) ?? .low },
            set: { thresholdRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Default Security Policy") {
                Toggle("Allow Sudo Commands", isOn: $allowSudo)
                    .tint(.orange)

                if allowSudo {
                    Label("Sudo access enables privileged operations. Use with caution.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Toggle("Require Approval for Risky Actions", isOn: $requireApproval)

                Picker("Auto-Approve Threshold", selection: autoApproveThreshold) {
                    ForEach([RiskLevel.low, .medium, .high, .critical], id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }

                Text("Actions at or below this risk level will be approved automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Audit Logging") {
                Toggle("Enable Audit Logs", isOn: $enableAuditLogs)

                Button("Export Audit Logs…") {
                    exportAuditLogs()
                }
                .disabled(!enableAuditLogs)
            }

            Section("Blocked Commands") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("These commands are always blocked regardless of agent settings:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(AppConfig.defaultSecurityPolicy.blacklistedCommands, id: \.self) { cmd in
                        Text(cmd)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.08))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func exportAuditLogs() {
        Task {
            let logger = AuditLogger.shared
            let query = AuditQuery()
            if let url = try? await logger.export(query) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon + name
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "cpu")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 4) {
                        Text("Lumi Agent")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("Version \(AppConfig.version) (\(AppConfig.buildNumber))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("AI-powered agentic platform for macOS.\nChat with agents, build groups, automate tasks.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.callout)

                Divider()

                // Feature grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    FeatureCell(icon: "brain", color: .green, title: "OpenAI", detail: "GPT-4o & more")
                    FeatureCell(icon: "sparkles", color: .purple, title: "Anthropic", detail: "Claude models")
                    FeatureCell(icon: "atom", color: .blue, title: "Gemini", detail: "Google AI models")
                    FeatureCell(icon: "server.rack", color: .orange, title: "Ollama", detail: "Run locally")
                    FeatureCell(icon: "bubble.left.and.bubble.right.fill", color: .teal, title: "Agent Space", detail: "Chat & groups")
                    FeatureCell(icon: "shield.fill", color: .indigo, title: "Security", detail: "Approval flows")
                }

                Divider()

                Text("Built with SwiftUI · macOS 14+")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(28)
        }
    }
}

private struct FeatureCell: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Info Row (kept for compatibility)

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}
