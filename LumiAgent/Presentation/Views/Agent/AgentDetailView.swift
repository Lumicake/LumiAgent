//
//  AgentDetailView.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import SwiftUI

struct AgentDetailView: View {
    let agent: Agent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(agent.name)
                            .font(.largeTitle)
                        Text(agent.configuration.provider.rawValue)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: agent.status)
                }

                Divider()

                // Configuration
                GroupBox("Configuration") {
                    VStack(alignment: .leading, spacing: 12) {
                        ConfigRow(label: "Model", value: agent.configuration.model)
                        ConfigRow(label: "Temperature", value: String(format: "%.2f", agent.configuration.temperature ?? 0.7))
                        ConfigRow(label: "Max Tokens", value: "\(agent.configuration.maxTokens ?? 4096)")
                    }
                    .padding(.vertical, 8)
                }

                // Capabilities
                GroupBox("Capabilities") {
                    FlowLayout(spacing: 8) {
                        ForEach(agent.capabilities, id: \.self) { capability in
                            CapabilityBadge(capability: capability)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Security Policy
                GroupBox("Security Policy") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Allow Sudo", isOn: .constant(agent.configuration.securityPolicy.allowSudo))
                            .disabled(true)
                        Toggle("Require Approval", isOn: .constant(agent.configuration.securityPolicy.requireApproval))
                            .disabled(true)
                        ConfigRow(label: "Max Execution Time", value: "\(Int(agent.configuration.securityPolicy.maxExecutionTime))s")
                    }
                    .padding(.vertical, 8)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Agent Details")
    }
}

struct ConfigRow: View {
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

struct CapabilityBadge: View {
    let capability: AgentCapability

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(capability.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var icon: String {
        switch capability {
        case .fileOperations: return "doc.fill"
        case .webSearch: return "magnifyingglass"
        case .codeExecution: return "terminal.fill"
        case .systemCommands: return "command"
        case .databaseAccess: return "cylinder.fill"
        case .networkRequests: return "network"
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
