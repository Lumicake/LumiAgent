//
//  SettingsView.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import SwiftUI

struct SettingsView: View {
    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var ollamaURL: String = "http://localhost:11434"
    @FocusState private var focusedField: Field?

    enum Field {
        case openAI
        case anthropic
        case ollama
    }

    var body: some View {
        TabView {
            // API Keys
            Form {
                Section("OpenAI") {
                    SecureField("API Key", text: $openAIKey)
                        .focused($focusedField, equals: .openAI)
                        .textFieldStyle(.roundedBorder)

                    Button("Save OpenAI Key") {
                        saveAPIKey(openAIKey, for: .openai)
                        openAIKey = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(openAIKey.isEmpty)
                }

                Section("Anthropic") {
                    SecureField("API Key", text: $anthropicKey)
                        .focused($focusedField, equals: .anthropic)
                        .textFieldStyle(.roundedBorder)

                    Button("Save Anthropic Key") {
                        saveAPIKey(anthropicKey, for: .anthropic)
                        anthropicKey = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(anthropicKey.isEmpty)
                }

                Section("Ollama") {
                    TextField("Server URL", text: $ollamaURL)
                        .focused($focusedField, equals: .ollama)
                        .textFieldStyle(.roundedBorder)

                    Text("Default: http://localhost:11434")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("API Keys", systemImage: "key.fill")
            }

            // Security
            Form {
                Section("Default Security Policy") {
                    Toggle("Allow Sudo Commands", isOn: .constant(false))
                    Toggle("Require Approval for Risky Operations", isOn: .constant(true))

                    Picker("Auto-Approve Threshold", selection: .constant(RiskLevel.low)) {
                        ForEach([RiskLevel.low, .medium, .high, .critical], id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }

                Section("Audit Logging") {
                    Toggle("Enable Audit Logs", isOn: .constant(true))
                    Button("Export Audit Logs") {
                        exportAuditLogs()
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Security", systemImage: "shield.fill")
            }

            // About
            VStack(spacing: 16) {
                Image(systemName: "cpu")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Lumi Agent")
                    .font(.title)

                Text("Version 1.0.0")
                    .foregroundStyle(.secondary)

                Text("AI-powered agentic platform for macOS")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.vertical)

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "OpenAI Support", value: "✓")
                    InfoRow(label: "Anthropic Support", value: "✓")
                    InfoRow(label: "Ollama Support", value: "✓")
                    InfoRow(label: "Audit Logging", value: "✓")
                    InfoRow(label: "Security Policies", value: "✓")
                }
            }
            .padding()
            .tabItem {
                Label("About", systemImage: "info.circle.fill")
            }
        }
        .frame(width: 600, height: 500)
    }

    private func saveAPIKey(_ key: String, for provider: AIProvider) {
        let repo = AIProviderRepository()
        do {
            try repo.setAPIKey(key, for: provider)
            print("✅ API key saved for \(provider.rawValue)")
        } catch {
            print("❌ Failed to save API key: \(error)")
        }
    }

    private func exportAuditLogs() {
        Task {
            let logger = AuditLogger.shared
            let query = AuditQuery()
            if let url = try? await logger.export(query) {
                print("Exported to: \(url)")
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
