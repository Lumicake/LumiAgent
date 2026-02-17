# 🚀 Lumi Agent - Quick Start Guide

## The UI Interaction Issue

You're experiencing locked buttons/textboxes because the app is running as a **Swift Package** instead of a proper **macOS App Bundle**. Here's how to fix it:

## ✅ Solution 1: Run from Xcode (Recommended)

1. **Open in Xcode:**
   ```bash
   open Package.swift
   ```

2. **In Xcode:**
   - Wait for package resolution to complete
   - Top toolbar: Select **"LumiAgent"** scheme
   - Select **"My Mac"** as destination
   - Press **⌘R** (or click Play ▶️)

3. **Grant Permissions:**
   - When prompted, allow any permissions the app requests
   - The app should now be fully interactive!

## ✅ Solution 2: Run from Terminal

```bash
./run_app.sh
```

This script:
- Builds the app
- Sets proper bundle identifier
- Launches with correct environment

## ✅ Solution 3: Create App Bundle

For a standalone app that works like normal macOS apps:

1. **Build release version:**
   ```bash
   swift build -c release
   ```

2. **Create app bundle:**
   ```bash
   # Create structure
   mkdir -p LumiAgent.app/Contents/MacOS

   # Copy executable
   cp .build/release/LumiAgent LumiAgent.app/Contents/MacOS/

   # Create Info.plist (see below)
   ```

3. **Launch:**
   ```bash
   open LumiAgent.app
   ```

## 🔍 Troubleshooting

### Issue: Text fields not accepting input

**Cause:** Missing bundle identifier when running as Swift Package

**Fix:** Use one of the solutions above

### Issue: Buttons don't respond to clicks

**Cause:** Same as above - app not properly registered with macOS

**Fix:** Run from Xcode or create proper app bundle

### Issue: "Cannot index window tabs"

**Cause:** Missing CFBundleIdentifier

**Fix:** The Info.plist in `LumiAgent/Resources/` should be automatically included

## 📋 Verify It's Working

1. Click **"New Agent"** button in toolbar
2. Type in the "Name" field
3. Select a provider from dropdown
4. Click "Create"

If all of these work, you're good to go! ✅

## 🎯 Next Steps

Once the app is running properly:

1. **Add API Keys:**
   - Click Settings (gear icon)
   - Enter your OpenAI/Anthropic API key
   - Click Save

2. **Create Your First Agent:**
   - Click "New Agent" (⌘N)
   - Name it (e.g., "My Assistant")
   - Choose provider (Ollama for local, no API key needed)
   - Click Create

3. **Test It:**
   - Select your agent
   - Click Execute (⌘R)
   - The agent will start running!

## 💡 Pro Tips

- **Keyboard Shortcuts:**
  - ⌘N - New Agent
  - ⌘R - Execute Agent
  - ⌘. - Stop Execution
  - ⌘1-4 - Switch views

- **Local AI (No API Key):**
  - Install Ollama: `brew install ollama`
  - Start it: `ollama serve`
  - Pull a model: `ollama pull llama3`
  - Create agent with Ollama provider

- **Security:**
  - All commands require approval by default
  - Check Audit Logs to see what happened
  - Customize security policies per agent

## 🆘 Still Having Issues?

Run this diagnostic:

```bash
# Check if app is built
ls -la .build/debug/LumiAgent

# Try running directly
.build/debug/LumiAgent

# Check for errors
echo "If you see any errors above, that's the issue!"
```

**Most common fix:** Just run from Xcode with ⌘R 🎯
