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

    /// Get tools for AI (as AITool format). If enabledNames is empty, returns all tools.
    func getToolsForAI(enabledNames: [String] = []) -> [AITool] {
        let all = tools.values
        if enabledNames.isEmpty {
            return all.map { $0.toAITool() }
        }
        return all
            .filter { enabledNames.contains($0.name) }
            .map { $0.toAITool() }
    }

    // MARK: - Built-in Tools

    private func registerBuiltInTools() {

        // MARK: File Operations

        register(RegisteredTool(
            name: "read_file",
            description: "Read the contents of a file at the given path",
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
            description: "Write content to a file, creating it if it doesn't exist",
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
            description: "List files and directories in a given path",
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

        register(RegisteredTool(
            name: "create_directory",
            description: "Create a directory (and any intermediate directories) at the given path",
            category: .fileOperations,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Absolute path of the directory to create"
                    )
                ],
                required: ["path"]
            ),
            handler: { args in
                try await FileSystemTools.createDirectory(path: args["path"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "delete_file",
            description: "Delete a file or directory at the given path",
            category: .fileOperations,
            riskLevel: .high,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Absolute path of the file or directory to delete"
                    )
                ],
                required: ["path"]
            ),
            handler: { args in
                try await FileSystemTools.deleteFile(path: args["path"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "move_file",
            description: "Move or rename a file or directory",
            category: .fileOperations,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "source": AIToolProperty(
                        type: "string",
                        description: "Source path"
                    ),
                    "destination": AIToolProperty(
                        type: "string",
                        description: "Destination path"
                    )
                ],
                required: ["source", "destination"]
            ),
            handler: { args in
                try await FileSystemTools.moveFile(
                    source: args["source"] ?? "",
                    destination: args["destination"] ?? ""
                )
            }
        ))

        register(RegisteredTool(
            name: "copy_file",
            description: "Copy a file or directory to a new location",
            category: .fileOperations,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "source": AIToolProperty(
                        type: "string",
                        description: "Source path"
                    ),
                    "destination": AIToolProperty(
                        type: "string",
                        description: "Destination path"
                    )
                ],
                required: ["source", "destination"]
            ),
            handler: { args in
                try await FileSystemTools.copyFile(
                    source: args["source"] ?? "",
                    destination: args["destination"] ?? ""
                )
            }
        ))

        register(RegisteredTool(
            name: "search_files",
            description: "Recursively search for files matching a pattern in a directory",
            category: .fileOperations,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "directory": AIToolProperty(
                        type: "string",
                        description: "Directory to search in"
                    ),
                    "pattern": AIToolProperty(
                        type: "string",
                        description: "Regex or glob pattern to match file names against"
                    )
                ],
                required: ["directory", "pattern"]
            ),
            handler: { args in
                try await FileSystemTools.searchFiles(
                    directory: args["directory"] ?? "",
                    pattern: args["pattern"] ?? ""
                )
            }
        ))

        register(RegisteredTool(
            name: "get_file_info",
            description: "Get metadata about a file or directory (size, dates, type, permissions)",
            category: .fileOperations,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Absolute path to the file or directory"
                    )
                ],
                required: ["path"]
            ),
            handler: { args in
                try await FileSystemTools.getFileInfo(path: args["path"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "append_to_file",
            description: "Append content to the end of a file",
            category: .fileOperations,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Absolute path to the file"
                    ),
                    "content": AIToolProperty(
                        type: "string",
                        description: "Content to append"
                    )
                ],
                required: ["path", "content"]
            ),
            handler: { args in
                try await FileSystemTools.appendToFile(
                    path: args["path"] ?? "",
                    content: args["content"] ?? ""
                )
            }
        ))

        // MARK: System Commands

        register(RegisteredTool(
            name: "execute_command",
            description: "Execute a shell command and return its output",
            category: .systemCommands,
            riskLevel: .high,
            parameters: AIToolParameters(
                properties: [
                    "command": AIToolProperty(
                        type: "string",
                        description: "Shell command to execute"
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

        register(RegisteredTool(
            name: "get_current_datetime",
            description: "Get the current date and time",
            category: .systemCommands,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [:],
                required: []
            ),
            handler: { _ in
                try await SystemTools.getCurrentDatetime()
            }
        ))

        register(RegisteredTool(
            name: "get_system_info",
            description: "Get information about the system (OS, CPU, memory)",
            category: .systemCommands,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [:],
                required: []
            ),
            handler: { _ in
                try await SystemTools.getSystemInfo()
            }
        ))

        register(RegisteredTool(
            name: "list_processes",
            description: "List the top running processes sorted by CPU usage",
            category: .systemCommands,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [:],
                required: []
            ),
            handler: { _ in
                try await SystemTools.listRunningProcesses()
            }
        ))

        // MARK: Network Requests

        register(RegisteredTool(
            name: "fetch_url",
            description: "Fetch content from a URL using an HTTP GET request",
            category: .networkRequests,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "url": AIToolProperty(
                        type: "string",
                        description: "The URL to fetch"
                    )
                ],
                required: ["url"]
            ),
            handler: { args in
                try await NetworkTools.fetchURL(url: args["url"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "http_request",
            description: "Make an HTTP request with custom method, headers, and body",
            category: .networkRequests,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "url": AIToolProperty(
                        type: "string",
                        description: "The URL to request"
                    ),
                    "method": AIToolProperty(
                        type: "string",
                        description: "HTTP method (GET, POST, PUT, DELETE, PATCH, etc.)",
                        enumValues: ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
                    ),
                    "headers": AIToolProperty(
                        type: "string",
                        description: "JSON string of request headers (optional)"
                    ),
                    "body": AIToolProperty(
                        type: "string",
                        description: "Request body string (optional)"
                    )
                ],
                required: ["url", "method"]
            ),
            handler: { args in
                try await NetworkTools.httpRequest(
                    url: args["url"] ?? "",
                    method: args["method"] ?? "GET",
                    headers: args["headers"],
                    body: args["body"]
                )
            }
        ))

        register(RegisteredTool(
            name: "web_search",
            description: "Search the web for information using DuckDuckGo",
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
                try await NetworkTools.webSearch(query: args["query"] ?? "")
            }
        ))

        // MARK: Git

        register(RegisteredTool(
            name: "git_status",
            description: "Show the working tree status of a git repository",
            category: .git,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "directory": AIToolProperty(
                        type: "string",
                        description: "Path to the git repository"
                    )
                ],
                required: ["directory"]
            ),
            handler: { args in
                try await GitTools.status(directory: args["directory"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "git_log",
            description: "Show recent git commit history",
            category: .git,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "directory": AIToolProperty(
                        type: "string",
                        description: "Path to the git repository"
                    ),
                    "limit": AIToolProperty(
                        type: "string",
                        description: "Number of commits to show (default: 10)"
                    )
                ],
                required: ["directory"]
            ),
            handler: { args in
                let limit = Int(args["limit"] ?? "10") ?? 10
                return try await GitTools.log(directory: args["directory"] ?? "", limit: limit)
            }
        ))

        register(RegisteredTool(
            name: "git_diff",
            description: "Show changes in the working tree or staged changes",
            category: .git,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "directory": AIToolProperty(
                        type: "string",
                        description: "Path to the git repository"
                    ),
                    "staged": AIToolProperty(
                        type: "string",
                        description: "Set to 'true' to show staged (cached) changes only"
                    )
                ],
                required: ["directory"]
            ),
            handler: { args in
                let staged = args["staged"]?.lowercased() == "true"
                return try await GitTools.diff(directory: args["directory"] ?? "", staged: staged)
            }
        ))

        register(RegisteredTool(
            name: "git_commit",
            description: "Stage all changes and create a git commit",
            category: .git,
            riskLevel: .high,
            parameters: AIToolParameters(
                properties: [
                    "directory": AIToolProperty(
                        type: "string",
                        description: "Path to the git repository"
                    ),
                    "message": AIToolProperty(
                        type: "string",
                        description: "Commit message"
                    )
                ],
                required: ["directory", "message"]
            ),
            handler: { args in
                try await GitTools.commit(
                    directory: args["directory"] ?? "",
                    message: args["message"] ?? ""
                )
            }
        ))

        register(RegisteredTool(
            name: "git_branch",
            description: "List branches or create a new branch",
            category: .git,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "directory": AIToolProperty(
                        type: "string",
                        description: "Path to the git repository"
                    ),
                    "create": AIToolProperty(
                        type: "string",
                        description: "Name of the new branch to create (optional; omit to list branches)"
                    )
                ],
                required: ["directory"]
            ),
            handler: { args in
                try await GitTools.branch(
                    directory: args["directory"] ?? "",
                    create: args["create"]
                )
            }
        ))

        register(RegisteredTool(
            name: "git_clone",
            description: "Clone a git repository to a local destination",
            category: .git,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "url": AIToolProperty(
                        type: "string",
                        description: "Repository URL to clone"
                    ),
                    "destination": AIToolProperty(
                        type: "string",
                        description: "Local path to clone into"
                    )
                ],
                required: ["url", "destination"]
            ),
            handler: { args in
                try await GitTools.clone(
                    url: args["url"] ?? "",
                    destination: args["destination"] ?? ""
                )
            }
        ))

        // MARK: Text / Data

        register(RegisteredTool(
            name: "search_in_file",
            description: "Search for a pattern in a file and return matching lines with context",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Absolute path to the file"
                    ),
                    "pattern": AIToolProperty(
                        type: "string",
                        description: "Regular expression or string to search for"
                    )
                ],
                required: ["path", "pattern"]
            ),
            handler: { args in
                try await DataTools.searchInFile(
                    path: args["path"] ?? "",
                    pattern: args["pattern"] ?? ""
                )
            }
        ))

        register(RegisteredTool(
            name: "replace_in_file",
            description: "Replace all occurrences of a string in a file",
            category: .textData,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Absolute path to the file"
                    ),
                    "search": AIToolProperty(
                        type: "string",
                        description: "String to search for"
                    ),
                    "replacement": AIToolProperty(
                        type: "string",
                        description: "Replacement string"
                    )
                ],
                required: ["path", "search", "replacement"]
            ),
            handler: { args in
                try await DataTools.replaceInFile(
                    path: args["path"] ?? "",
                    search: args["search"] ?? "",
                    replacement: args["replacement"] ?? ""
                )
            }
        ))

        register(RegisteredTool(
            name: "calculate",
            description: "Evaluate a mathematical expression using Python",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "expression": AIToolProperty(
                        type: "string",
                        description: "Mathematical expression to evaluate (supports math module)"
                    )
                ],
                required: ["expression"]
            ),
            handler: { args in
                try await DataTools.calculate(expression: args["expression"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "parse_json",
            description: "Pretty-print and validate a JSON string",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "input": AIToolProperty(
                        type: "string",
                        description: "JSON string to parse and pretty-print"
                    )
                ],
                required: ["input"]
            ),
            handler: { args in
                try await DataTools.parseJSON(input: args["input"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "encode_base64",
            description: "Encode a string to Base64",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "input": AIToolProperty(
                        type: "string",
                        description: "String to encode"
                    )
                ],
                required: ["input"]
            ),
            handler: { args in
                try await DataTools.encodeBase64(input: args["input"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "decode_base64",
            description: "Decode a Base64-encoded string",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "input": AIToolProperty(
                        type: "string",
                        description: "Base64-encoded string to decode"
                    )
                ],
                required: ["input"]
            ),
            handler: { args in
                try await DataTools.decodeBase64(input: args["input"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "count_lines",
            description: "Count the number of lines in a file",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Absolute path to the file"
                    )
                ],
                required: ["path"]
            ),
            handler: { args in
                try await DataTools.countLines(path: args["path"] ?? "")
            }
        ))

        // MARK: Clipboard

        register(RegisteredTool(
            name: "read_clipboard",
            description: "Read the current contents of the clipboard",
            category: .clipboard,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [:],
                required: []
            ),
            handler: { _ in
                try await ClipboardTools.read()
            }
        ))

        register(RegisteredTool(
            name: "write_clipboard",
            description: "Write content to the clipboard",
            category: .clipboard,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "content": AIToolProperty(
                        type: "string",
                        description: "Content to write to the clipboard"
                    )
                ],
                required: ["content"]
            ),
            handler: { args in
                try await ClipboardTools.write(content: args["content"] ?? "")
            }
        ))

        // MARK: Screenshot

        register(RegisteredTool(
            name: "take_screenshot",
            description: "Take a screenshot and save it to a file",
            category: .screenshot,
            riskLevel: .medium,
            parameters: AIToolParameters(
                properties: [
                    "path": AIToolProperty(
                        type: "string",
                        description: "Destination file path (default: ~/Desktop/screenshot.png)"
                    )
                ],
                required: []
            ),
            handler: { args in
                try await MediaTools.takeScreenshot(path: args["path"] ?? "")
            }
        ))

        // MARK: Code Execution

        register(RegisteredTool(
            name: "run_python",
            description: "Execute Python 3 code and return its output",
            category: .codeExecution,
            riskLevel: .high,
            parameters: AIToolParameters(
                properties: [
                    "code": AIToolProperty(
                        type: "string",
                        description: "Python 3 code to execute"
                    )
                ],
                required: ["code"]
            ),
            handler: { args in
                try await CodeTools.runPython(code: args["code"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "run_node",
            description: "Execute Node.js code and return its output",
            category: .codeExecution,
            riskLevel: .high,
            parameters: AIToolParameters(
                properties: [
                    "code": AIToolProperty(
                        type: "string",
                        description: "Node.js code to execute"
                    )
                ],
                required: ["code"]
            ),
            handler: { args in
                try await CodeTools.runNode(code: args["code"] ?? "")
            }
        ))

        // MARK: Memory

        register(RegisteredTool(
            name: "memory_save",
            description: "Persist a key-value pair to long-term memory",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "key": AIToolProperty(
                        type: "string",
                        description: "Memory key"
                    ),
                    "value": AIToolProperty(
                        type: "string",
                        description: "Value to store"
                    )
                ],
                required: ["key", "value"]
            ),
            handler: { args in
                try await MemoryTools.save(key: args["key"] ?? "", value: args["value"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "memory_read",
            description: "Read a value from long-term memory by key",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "key": AIToolProperty(
                        type: "string",
                        description: "Memory key to look up"
                    )
                ],
                required: ["key"]
            ),
            handler: { args in
                try await MemoryTools.read(key: args["key"] ?? "")
            }
        ))

        register(RegisteredTool(
            name: "memory_list",
            description: "List all keys stored in long-term memory",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [:],
                required: []
            ),
            handler: { _ in
                try await MemoryTools.list()
            }
        ))

        register(RegisteredTool(
            name: "memory_delete",
            description: "Delete a key from long-term memory",
            category: .textData,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "key": AIToolProperty(
                        type: "string",
                        description: "Memory key to delete"
                    )
                ],
                required: ["key"]
            ),
            handler: { args in
                try await MemoryTools.delete(key: args["key"] ?? "")
            }
        ))

        // MARK: Self-Modification
        // Intercepted by AppState.streamResponse — handler here is a placeholder only.

        register(RegisteredTool(
            name: "update_self",
            description: "Update your own agent configuration. Use this when the user asks you to change your name, personality, system prompt, model, or temperature. Only call this when explicitly asked.",
            category: .systemCommands,
            riskLevel: .low,
            parameters: AIToolParameters(
                properties: [
                    "name": AIToolProperty(
                        type: "string",
                        description: "New agent name (optional)"
                    ),
                    "system_prompt": AIToolProperty(
                        type: "string",
                        description: "New system prompt that defines your personality and behavior (optional)"
                    ),
                    "model": AIToolProperty(
                        type: "string",
                        description: "New model to use, e.g. gpt-4o or claude-sonnet-4-6 (optional)"
                    ),
                    "temperature": AIToolProperty(
                        type: "string",
                        description: "New temperature between 0.0 (focused) and 1.0 (creative) (optional)"
                    )
                ],
                required: []
            ),
            handler: { _ in "Self-update applied." }
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

    var displayCategory: String {
        category.displayName
    }

    func toAITool() -> AITool {
        AITool(
            name: name,
            description: description,
            parameters: parameters
        )
    }
}

// MARK: - Tool Category

enum ToolCategory: String, CaseIterable {
    case fileOperations
    case systemCommands
    case webSearch
    case codeExecution
    case databaseAccess
    case networkRequests
    case git
    case textData
    case clipboard
    case screenshot

    var displayName: String {
        switch self {
        case .fileOperations:   return "File Operations"
        case .systemCommands:   return "System Commands"
        case .webSearch:        return "Web Search"
        case .codeExecution:    return "Code Execution"
        case .databaseAccess:   return "Database Access"
        case .networkRequests:  return "Network Requests"
        case .git:              return "Git"
        case .textData:         return "Text & Data"
        case .clipboard:        return "Clipboard"
        case .screenshot:       return "Screenshot"
        }
    }

    var icon: String {
        switch self {
        case .fileOperations:   return "doc.fill"
        case .systemCommands:   return "terminal.fill"
        case .webSearch:        return "magnifyingglass"
        case .codeExecution:    return "chevron.left.forwardslash.chevron.right"
        case .databaseAccess:   return "cylinder.fill"
        case .networkRequests:  return "network"
        case .git:              return "arrow.triangle.branch"
        case .textData:         return "text.alignleft"
        case .clipboard:        return "clipboard.fill"
        case .screenshot:       return "camera.fill"
        }
    }
}

// MARK: - Tool Handler

typealias ToolHandler = ([String: String]) async throws -> String

// MARK: - Legacy Tool Handlers (kept for backward compatibility)

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
        let itemNames = items.map { $0.lastPathComponent }.sorted().joined(separator: "\n")
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
