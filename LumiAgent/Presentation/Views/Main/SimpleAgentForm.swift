//
//  SimpleAgentForm.swift
//  LumiAgent
//
//  Quick test form for debugging
//

import SwiftUI

struct SimpleAgentForm: View {
    @Environment(\.dismiss) var dismiss
    @State private var agentName = ""
    @State private var selectedProvider = AIProvider.ollama

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Agent")
                .font(.title)

            VStack(alignment: .leading, spacing: 8) {
                Text("Agent Name:")
                TextField("Enter name", text: $agentName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Provider:")
                Picker("Provider", selection: $selectedProvider) {
                    Text("OpenAI").tag(AIProvider.openai)
                    Text("Anthropic").tag(AIProvider.anthropic)
                    Text("Ollama").tag(AIProvider.ollama)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    print("Creating agent: \(agentName)")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(agentName.isEmpty)
            }
        }
        .padding(40)
        .frame(width: 400, height: 300)
    }
}
