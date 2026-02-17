#!/bin/bash
# Launch Lumi Agent with proper bundle identifier

set -e  # Exit on error

echo "🚀 Lumi Agent Launcher"
echo "====================="
echo ""

# Set bundle identifier in environment
export PRODUCT_BUNDLE_IDENTIFIER="com.lumiagent.app"
export PRODUCT_NAME="LumiAgent"
export CFBundleIdentifier="com.lumiagent.app"

echo "📦 Bundle ID: $PRODUCT_BUNDLE_IDENTIFIER"
echo ""

echo "🔨 Building..."
swift build -c debug

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "🎨 Launching Lumi Agent..."
    echo "   (Press Ctrl+C to stop)"
    echo ""

    # Launch with bundle ID set
    PRODUCT_BUNDLE_IDENTIFIER="com.lumiagent.app" \
    CFBundleIdentifier="com.lumiagent.app" \
    .build/debug/LumiAgent
else
    echo "❌ Build failed"
    exit 1
fi
