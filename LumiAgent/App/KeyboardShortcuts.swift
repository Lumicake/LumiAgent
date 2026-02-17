//
//  KeyboardShortcuts.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//
//  Keyboard shortcuts and commands
//

import SwiftUI

// MARK: - App Commands

struct LumiAgentCommands: Commands {
    @Binding var selectedSidebarItem: SidebarItem

    var body: some Commands {
        // View Menu
        CommandMenu("View") {
            Button("Agents") {
                selectedSidebarItem = .agents
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("History") {
                selectedSidebarItem = .history
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Approval Queue") {
                selectedSidebarItem = .queue
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Audit Logs") {
                selectedSidebarItem = .audit
            }
            .keyboardShortcut("4", modifiers: .command)

            Divider()

            Button("Refresh") {
                // Trigger refresh
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        // Agent Menu
        CommandMenu("Agent") {
            Button("Create New Agent") {
                // Trigger new agent
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Duplicate Agent") {
                // Duplicate selected agent
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(true)

            Button("Delete Agent") {
                // Delete selected agent
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(true)

            Divider()

            Button("Execute") {
                // Execute agent
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(true)

            Button("Stop") {
                // Stop execution
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(true)
        }

        // Help Menu
        CommandGroup(replacing: .help) {
            Button("Lumi Agent Help") {
                if let url = URL(string: "https://github.com/yourusername/lumi-agent") {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("Report Issue") {
                if let url = URL(string: "https://github.com/yourusername/lumi-agent/issues") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button("View Logs") {
                openLogsDirectory()
            }
        }
    }

    private func openLogsDirectory() {
        let fileManager = FileManager.default
        if let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            let logsURL = appSupport.appendingPathComponent("LumiAgent")
            NSWorkspace.shared.open(logsURL)
        }
    }
}
