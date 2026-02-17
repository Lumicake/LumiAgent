//
//  ToolRegistry.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//
//  Central registry for all available tools
//

import Foundation

// MARK: - Tool Registry

/// Manages available tools and their definitions
final class ToolRegistry {
    // MARK: - Singleton

    static let shared = ToolRegistry()

    // MARK: - Properties

    private var tools: [String: RegisteredTool] = [:]

    // MARK: - Initialization

    private init() {
        registerBuiltInTools()
    }

    // MARK: - Registration

    /// Register a tool
    func register(_ tool: RegisteredTool) {
        tools[tool.name] = tool
    }

    /// Get a tool by name
    func getTool(named name: String) -> RegisteredTool? {
        tools[name]
    }

    /// Get all tools
    func getAllTools() -> [RegisteredTool] {
        Array(tools.values)
    }

    /// Get tools for AI (as AITool format)
    func getToolsForAI() -> [AITool] {
        tools.values.map { $0.toAITool() }
    }

    // MARK: - Built-in Tools

    private func registerBuiltInTools() {
        // File operations
        register(RegisteredTool(
            name: "read_file",
            description: "Read contents of a file",
            category: .fileOperations,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Absolute path to the file to read"
                    )
                ],
                required: ["path"]
            ),
            handler: { args in
                try await FileOperationHandler.readFile(path: args["path"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "write_file",
            description: "Write content to a file",
            category: .fileOperations,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Absolute path to the file to write"
                    ),
                    "content": AIToolProperty(
                        type: "string",
                        description: "Content to write to the file"
                    )
                ],
                required: ["path", "content"]
            ),
            handler: { args in
                try await FileOperationHandler.writeFile(
                    path: args["path"] ?? "",
                    content: args["content"] ?? ""
                )
            }
        ))

        register(RegisteredTool(
            name: "list_directory",
            description: "List files and directories in a path",
            category: .fileOperations,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Directory path to list"
                    )
                ],
                required: ["path"]
            ),
            handler: { args in
                try await FileOperationHandler.listDirectory(path: args["path"] ?? "")
            }
        ))

        // System commands
        register(RegisteredTool(
            name: "execute_command",
            description: "Execute a shell command",
            category: .systemCommands,
            riskLevel: .high,
            parameters: AIToolParameters(
                properties: [
                    "command": AIToolProperty(
                        type: "string",
                        description: "Command to execute"
                    ),
                    "working_directory": AIToolProperty(
                        type: "string",
                        description: "Working directory for the command (optional)"
                    )
                ],
                required: ["command"]
            ),
            handler: { args in
                try await SystemCommandHandler.executeCommand(
                    command: args["command"] ?? "",
                    workingDirectory: args["working_directory"]
                )
            }
        ))

        // Web search
        register(RegisteredTool(
            name: "web_search",
            description: "Search the web for information",
            category: .webSearch,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "query": AIToolProperty(
                        type: "string",
                        description: "Search query"
                    )
                ],
                required: ["query"]
            ),
            handler: { args in
                try await WebSearchHandler.search(query: args["query"] ?? "")
            }
        ))

        // Database operations
        register(RegisteredTool(
            name: "query_database",
            description: "Query a database using SQL",
            category: .databaseAccess,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "query": AIToolProperty(
                        type: "string",
                        description: "SQL query to execute"
                    )
                ],
                required: ["query"]
            ),
            handler: { args in
                try await DatabaseHandler.executeQuery(query: args["query"] ?? "")
            }
        ))
    }
}

// MARK: - Registered Tool

struct RegisteredTool {
    let name: String
    let description: String
    let category: ToolCategory
    let riskLevel: RiskLevel
    let parameters: AIToolParameters
    let handler: ToolHandler

    func toAITool() -> AITool {
        AITool(
            name: name,
            description: description,
            parameters: parameters
        )
    }
}

// MARK: - Tool Category

enum ToolCategory: String {
    case fileOperations
    case systemCommands
    case webSearch
    case codeExecution
    case databaseAccess
    case networkRequests
}

// MARK: - Tool Handler

typealias ToolHandler = ([String: String]) async throws -> String

// MARK: - Tool Handlers

enum FileOperationHandler {
    static func readFile(path: String) async throws -> String {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw ToolError.fileNotFound(path)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func writeFile(path: String, content: String) async throws -> String {
        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return "File written successfully: \(path)"
    }

    static func listDirectory(path: String) async throws -> String {
        let url = URL(fileURLWithPath: path)
        let items = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
        let itemNames = items.map { $0.lastPathComponent }.joined(separator: "\n")
        return itemNames
    }
}

enum SystemCommandHandler {
    static func executeCommand(
        command: String,
        workingDirectory: String?
    ) async throws -> String {
        let executor = ProcessExecutor()
        let parts = command.split(separator: " ").map(String.init)
        guard let cmd = parts.first else {
            throw ToolError.invalidCommand
        }

        let args = Array(parts.dropFirst())
        let workDir = workingDirectory.map { URL(fileURLWithPath: $0) }

        let result = try await executor.execute(
            command: cmd,
            arguments: args,
            workingDirectory: workDir
        )

        if result.success {
            return result.output ?? ""
        } else {
            throw ToolError.commandFailed(result.error ?? "Unknown error")
        }
    }
}

enum WebSearchHandler {
    static func search(query: String) async throws -> String {
        // TODO: Implement actual web search
        // Could use DuckDuckGo API or other search service
        return "Web search not yet implemented. Query: \(query)"
    }
}

enum DatabaseHandler {
    static func executeQuery(query: String) async throws -> String {
        // TODO: Implement database query execution
        return "Database query not yet implemented. Query: \(query)"
    }
}

// MARK: - Tool Error

enum ToolError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidCommand
    case commandFailed(String)
    case permissionDenied
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidCommand:
            return "Invalid command format"
        case .commandFailed(let error):
            return "Command failed: \(error)"
        case .permissionDenied:
            return "Permission denied"
        case .notImplemented:
            return "Tool not yet implemented"
        }
    }
}
