# Lumi Agent

> An AI-powered agentic platform for macOS — chat with agents, build multi-agent groups, and let them automate tasks directly on your system.

**By LumiTech Group**


<img width="1211" height="764" alt="Screenshot 2026-02-20 at 1 12 55 AM" src="https://github.com/user-attachments/assets/d824314e-019f-47a6-a70a-47c9cd54161b" />

---

## ⚠️ Important: System Access Warning

**Lumi Agent operates with very high levels of access to your system.**

When tools are enabled, an agent can:

- Read, write, move, and delete **any file on your filesystem**
- Execute **arbitrary shell commands** via `/bin/bash`
- Open applications, URLs, and system utilities
- **Overwrite system-level files and run privileged operations when sudo access is granted** in Security Settings
- In **Agent Mode**: take full control of your mouse, keyboard, and screen

This is by design — Lumi is built to be a genuinely capable autonomous agent. With that power comes responsibility:

> **Always verify which agent you are talking to and which mode is active before granting elevated permissions. Do not enable sudo access or Agent Mode unless you fully trust the agent's configuration and the task it is performing.**

All tool calls pass through a risk-based approval system and are written to an immutable audit log. Shell execution operates within the macOS sandbox at the OS level — but no sandbox replaces careful judgment about what you ask an agent to do.

---

## Features

### Multi-AI Provider Support

| Provider | Models |
|---|---|
| **OpenAI** | o3, o4-mini, gpt-4.1, gpt-4.1-mini, gpt-4o, gpt-4o-mini |
| **Anthropic** | claude-opus-4-6, claude-sonnet-4-6, claude-haiku-4-5 |
| **Google Gemini** | gemini-2.5-pro, gemini-2.5-flash, gemini-2.0-flash, gemini-2.0-flash-lite |
| **Ollama** | llama3.3, qwen3, deepseek-r1, phi4, mistral, gemma3, codellama, llava + any local model |

### Agent Space

- Direct message any agent or build multi-agent **Group Chats**
- `@mention` routing — address specific agents in a group
- Agents see each other's messages in groups (context-aware multi-agent conversations)
- Live **streaming responses** with full markdown rendering
- Inline code blocks with language labels and horizontal scroll
<img width="1211" height="764" alt="Screenshot 2026-02-18 at 3 55 40 PM" src="https://github.com/user-attachments/assets/41604248-863c-4191-b26f-6a0a2bb9b39e" />


### Agent Mode — Screen Control

Activate **Agent Mode** in any direct message to grant the agent full control of your screen:

| Tool | What it does |
|---|---|
| `get_screen_info` | Screen size, cursor position, frontmost app |
| `move_mouse` | Move the cursor to any coordinate |
| `click_mouse` | Left/right click, single or double |
| `scroll_mouse` | Scroll wheel at any position |
| `type_text` | Type a string into the focused window |
| `press_key` | Press named keys with modifiers (⌘, ⇧, ⌥, ⌃) |
| `run_applescript` | Execute AppleScript — full System Events / accessibility access |
| `take_screenshot` | Capture the screen so the agent can observe state |

> Requires **Accessibility access**: System Settings → Privacy & Security → Accessibility → Lumi Agent
<img width="1392" height="764" alt="Screenshot 2026-02-20 at 1 05 52 AM" src="https://github.com/user-attachments/assets/4c2d0fc5-16eb-42bc-b286-9fb32db7ccd1" />


### Built-in Tool Library

| Category | Tools |
|---|---|
| File Operations | read, write, list, create, delete, move, copy, search, append |
| System Commands | shell (`/bin/bash`), open app, open URL, datetime, system info, process list |
| Web | Brave Search / DuckDuckGo, fetch URL, HTTP requests |
| Screen Control | mouse, keyboard, AppleScript, screenshot *(Agent Mode)* |
| Code Execution | Python 3, Node.js |
| Git | status, log, diff, commit, branch, clone |
| Text & Data | search/replace in file, calculate, parse JSON, base64, line count |
| Clipboard | read and write |
| Memory | persistent key-value store across conversations |
| Self-Modification | agents update their own name, prompt, model, and temperature on request |

### Security & Approval System

- **Risk-based approvals** — low-risk ops auto-approve, high-risk requires confirmation
- **Configurable threshold** — set the auto-approve ceiling in Security Settings
- **Command blocklist** — dangerous patterns always blocked regardless of agent config
- **Sudo toggle** — off by default; must be explicitly enabled per the warning above
- **Audit log** — immutable record of every tool execution (timestamp, agent, result)
- **CSV export** for compliance reporting

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ or Swift 5.9+ *(to build from source)*
- API keys for whichever cloud providers you use
- [Ollama](https://ollama.ai) *(only for local model support)*

---

## Installation

### Build from Source

```bash
git clone https://github.com/Lumicake/Agent-Lumi.git
cd Agent-Lumi
open Package.swift
```

Select the **LumiAgent** scheme, choose **My Mac** as the destination, and press `⌘R`.

---

## Quick Start

### 1. Add API Keys

Open **Settings** (`⌘,`) → **API Keys**:

- **OpenAI** — [platform.openai.com](https://platform.openai.com)
- **Anthropic** — [console.anthropic.com](https://console.anthropic.com)
- **Gemini** — [aistudio.google.com](https://aistudio.google.com)
- **Brave Search** *(optional, upgrades web search quality)* — [brave.com/search/api](https://brave.com/search/api/)
- **Ollama** — install locally, no key needed

### 2. Create an Agent

1. Go to **Agents** in the sidebar and click **New Agent** (`⌘N`)
2. Set a name, choose a provider and model
3. Write a system prompt *(optional)*
4. Enable the tools the agent should have access to
5. Click **Create**

### 3. Chat

- Click **Message** on any agent to open a DM
- Or select multiple agents and create a **Group Chat**
- Type and press `Return` — the agent reasons, calls tools, and streams its reply

### 4. Agent Mode *(optional)*

In a direct message, click the **Agent Mode** button in the chat header. The agent gains all screen control tools and will take a screenshot before acting. Grant Accessibility access when macOS prompts.

---

## Architecture

```
LumiAgent/
├── App/                    # Entry point, AppState, scene setup
├── Presentation/
│   └── Views/
│       ├── Agents/         # Agent list, detail, creation
│       ├── AgentSpace/     # Chat UI, bubbles, markdown, Agent Mode
│       ├── Settings/       # API keys, security policy, about
│       └── Shared/         # Reusable components
├── Domain/
│   ├── Models/             # Agent, Conversation, Message, Tool
│   ├── Services/           # ToolRegistry, MCPToolHandlers, ExecutionEngine
│   └── Repositories/       # Protocols
├── Data/
│   ├── Repositories/       # AI provider client, agent persistence
│   └── DataSources/        # GRDB database, provider implementations
└── Infrastructure/         # Security, audit logging, networking
```

### Key Components

| Component | Role |
|---|---|
| `AppState` | Central state — conversations, agent messaging, response streaming |
| `ToolRegistry` | Registers all tools; produces `AITool` definitions for provider API requests |
| `MCPToolHandlers` | Implements every tool handler (file, network, shell, screen, memory…) |
| `AIProviderRepository` | All four provider APIs — serializes tools and parses tool call responses |
| `AgentExecutionEngine` | Drives the agentic tool-loop for the task runner |
| `AuditLogger` | Appends an immutable record for every tool execution |

### Approval Flow

```
User message
  → Agent selects tool
      → Risk assessment  (low / medium / high / critical)
          → Auto-approve OR prompt user
              → Execute tool
                  → Result appended to conversation & audit log
                      → Agent continues reasoning
```

---

## Adding Custom Tools

```swift
ToolRegistry.shared.register(RegisteredTool(
    name: "my_tool",
    description: "Does something useful",
    category: .systemCommands,
    riskLevel: .medium,
    parameters: AIToolParameters(
        properties: [
            "input": AIToolProperty(type: "string", description: "Tool input")
        ],
        required: ["input"]
    ),
    handler: { args in
        return "Result: \(args["input"] ?? "")"
    }
))
```

---

## Dependencies

| Library | Purpose |
|---|---|
| [SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic) | Anthropic Claude API with streaming |
| [MacPaw/OpenAI](https://github.com/MacPaw/OpenAI) | OpenAI API client |
| [GRDB.swift](https://github.com/groue/GRDB.swift) | SQLite — agent configs and audit log |
| [swift-log](https://github.com/apple/swift-log) | Structured logging |

---

## Attribution

The core programming of Lumi Agent was carried out using **[Claude Code](https://claude.ai/claude-code)** by Anthropic — the official agentic CLI for Claude. The multi-provider AI layer, tool infrastructure, Agent Space chat system, multi-agent group messaging, markdown rendering, Agent Mode screen control, and security architecture were all built through Claude Code sessions.

---

## Star Growth

[![Star History Chart](https://api.star-history.com/svg?repos=Lumicake/Agent-Lumi&type=Date)](https://star-history.com/#Lumicake/Agent-Lumi&Date)

---

## Contributing

Contributions are welcome.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

Please keep the LumiTech Production License 1.0 attribution requirement intact in any derivative work.

---

## License

### LumiTech Production License 1.0

Copyright © 2026 LumiTech Group

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

**1. Attribution Requirement**
Any derivative work, fork, copy, or redistribution of this Software — whether in source or binary form — must include, in a prominent location within its own license file or documentation, a visible link back to the original repository:

```
Derived from / based on Lumi Agent by LumiTech Group
https://github.com/Lumicake/Agent-Lumi
```

**2. Notice Preservation**
The above copyright notice, this permission notice, and the attribution requirement in condition (1) must be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
