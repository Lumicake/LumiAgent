//
//  ContentView.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarItem.allCases, selection: $appState.selectedSidebarItem) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("Lumi Agent")
            .frame(minWidth: 200)
        } content: {
            // Content (list view based on sidebar selection)
            Group {
                switch appState.selectedSidebarItem {
                case .agents:
                    AgentListView()
                case .agentSpace:
                    AgentSpaceView()
                case .history:
                    Text("History - Coming Soon")
                case .queue:
                    Text("Approval Queue - Coming Soon")
                case .audit:
                    Text("Audit Logs - Coming Soon")
                case .settings:
                    Text("Settings - Coming Soon")
                }
            }
            .frame(minWidth: 300)
        } detail: {
            // Detail view
            Group {
                if let agentId = appState.selectedAgentId {
                    Text("Agent Detail: \(agentId)")
                } else {
                    Text("Select an item")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 400)
        }
    }
}

// This file is deprecated - MainWindow.swift is now the main entry point
