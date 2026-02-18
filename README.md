# Lumi Agent

A powerful AI-powered agentic platform for macOS, enabling autonomous AI agents to execute system commands with comprehensive security controls and audit logging.
<img width="1392" height="764" alt="Screenshot 2026-02-18 at 3 31 09 PM" src="https://github.com/user-attachments/assets/ba6be5db-a672-485e-a1f9-2d94ccccbb23" />


## Features

### 🤖 Multi-AI Provider Support
- **OpenAI** - GPT-4, GPT-4 Turbo
- **Anthropic** - Claude Opus 4, Sonnet 4, Haiku 4
- **Ollama** - Local models (Llama 3, Mixtral, CodeLlama, etc.)

### 🔒 Enterprise-Grade Security
- **5-Layer Security Model**
  - Policy Engine (whitelist/blacklist)
  - Risk Assessment (auto-classification)
  - Approval Flow (user confirmation)
  - Sandboxing (isolated execution)
  - Audit Trail (immutable logging)

- **Risk-Based Approvals**
  - Low: Auto-approve safe operations
  - Medium: User approval required
  - High: Approval + justification
  - Critical: Approval + authentication

### 🛠️ Built-in Tools
- File Operations (read, write, list)
- System Commands (shell execution)
- Web Search
- Database Queries
- Network Requests
- Code Execution

### 📊 Comprehensive Audit Logging
- Immutable audit trail
- Event tracking and filtering
- CSV export capability
- Compliance-ready reporting

### 🎨 Modern SwiftUI Interface
- Three-column navigation
- Real-time execution output
- Approval queue management
- Agent configuration
- Settings and preferences

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Option 1: Build from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/lumi-agent.git
   cd lumi-agent
   ```

2. **Open in Xcode**
   ```bash
   open Package.swift
   ```

3. **Build and Run**
   - Select **LumiAgent** scheme
   - Choose **My Mac** as destination
   - Press ⌘R to run

### Option 2: Download Release
- Download the latest release from [Releases](https://github.com/yourusername/lumi-agent/releases)
- Move to Applications folder
- Run Lumi Agent

## Quick Start

### 1. Configure API Keys

Go to **Settings** (⌘,) and enter your API keys:
- **OpenAI**: Get from [platform.openai.com](https://platform.openai.com)
- **Anthropic**: Get from [console.anthropic.com](https://console.anthropic.com)
- **Ollama**: Install from [ollama.ai](https://ollama.ai)

### 2. Create Your First Agent

1. Click **New Agent** (⌘N)
2. Enter agent name
3. Choose AI provider (OpenAI/Anthropic/Ollama)
4. Select model
5. Configure capabilities and security policy
6. Click **Create**

### 3. Execute Tasks

1. Select an agent from the list
2. Click **Execute** (⌘R)
3. Enter your task prompt
4. Monitor real-time execution
5. Approve operations when prompted

## Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────────┐
│     Presentation (SwiftUI)          │
├─────────────────────────────────────┤
│     Domain (Business Logic)         │
├─────────────────────────────────────┤
│     Data (Repositories & Sources)   │
├─────────────────────────────────────┤
│  Infrastructure (Security, Database)│
└─────────────────────────────────────┘
```

### Core Components

- **AgentExecutionEngine**: Orchestrates AI ↔ tool execution loop
- **ToolRegistry**: Manages available tools and handlers
- **AuthorizationManager**: Security gatekeeper with risk assessment
- **ApprovalFlow**: User approval queue and notifications
- **AuditLogger**: Immutable event logging

## Security Model

### Sandboxing
- Main app runs **fully sandboxed** (App Store compliant)
- Separate **privileged helper** for sudo operations via XPC
- Operations have timeouts and resource limits

### Approval Process
```
Command → Risk Assessment → Policy Check → Approval (if needed) → Execute → Audit Log
```

### Dangerous Operations
The following are automatically flagged as **critical**:
- `rm -rf /`
- `dd if=/dev/zero`
- Fork bombs
- System directory modifications
- Unrestricted `chmod` or `chown`

## Database Schema

Uses **GRDB.swift** with migrations:

- **agents** - Agent configurations
- **execution_sessions** - Execution history
- **approval_requests** - Approval queue
- **audit_logs** - Immutable audit trail

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | New Agent |
| ⌘R | Execute Agent |
| ⌘. | Stop Execution |
| ⌘, | Settings |
| ⌘1-4 | Switch views |
| ⌘⇧R | Refresh |

## Development

### Project Structure

```
LumiAgent/
├── App/                    # App entry point
├── Presentation/           # SwiftUI views
├── Domain/                 # Business logic
│   ├── Models/            # Core models
│   ├── Services/          # Execution engine, tools
│   └── Repositories/      # Repository protocols
├── Data/                   # Data sources
│   ├── Repositories/      # Implementations
│   └── DataSources/       # AI clients, database
└── Infrastructure/         # Security, logging, network
```

### Adding Custom Tools

```swift
// Register a new tool
ToolRegistry.shared.register(RegisteredTool(
    name: "my_tool",
    description: "Does something useful",
    category: .customCategory,
    riskLevel: .medium,
    parameters: AIToolParameters(
        properties: [
            "input": AIToolProperty(
                type: "string",
                description: "Tool input"
            )
        ],
        required: ["input"]
    ),
    handler: { args in
        // Tool implementation
        return "Result"
    }
))
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/lumi-agent/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/lumi-agent/discussions)
- **Documentation**: [Wiki](https://github.com/yourusername/lumi-agent/wiki)

## Acknowledgments

Built with:
- [SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic)
- [MacPaw/OpenAI](https://github.com/MacPaw/OpenAI)
- [GRDB.swift](https://github.com/groue/GRDB.swift)
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)

---

**Made with ❤️ using Claude Code**
