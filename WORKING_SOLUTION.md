# ✅ WORKING SOLUTION - How to Run Lumi Agent

## The Problem
You're seeing "Cannot index window tabs due to missing main bundle identifier" and UI elements are locked because Swift Package Manager executables don't have proper app bundle metadata.

## 🎯 THE FIX - Choose One:

---

### **Option 1: Use the Launch Script (Easiest)**

Simply run:
```bash
./run_app.sh
```

This script:
- Sets the bundle identifier
- Builds the app
- Launches with proper environment
- **UI should work perfectly!**

---

### **Option 2: Run in Xcode with Scheme Configuration**

1. **Open in Xcode:**
   ```bash
   open Package.swift
   ```

2. **Edit the Scheme:**
   - Top menu: **Product** → **Scheme** → **Edit Scheme...**
   - Select **Run** on the left
   - Go to **Arguments** tab
   - Under **Environment Variables**, click **+** and add:
     - Name: `PRODUCT_BUNDLE_IDENTIFIER`
     - Value: `com.lumiagent.app`
   - Click **Close**

3. **Run:**
   - Press **⌘R**
   - UI should now be fully interactive!

---

### **Option 3: Create a Real App Bundle**

For distribution/permanent solution:

```bash
# Build release
swift build -c release

# Create app structure
mkdir -p LumiAgent.app/Contents/MacOS
mkdir -p LumiAgent.app/Contents/Resources

# Copy executable
cp .build/release/LumiAgent LumiAgent.app/Contents/MacOS/

# Create Info.plist
cat > LumiAgent.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LumiAgent</string>
    <key>CFBundleIdentifier</key>
    <string>com.lumiagent.app</string>
    <key>CFBundleName</key>
    <string>LumiAgent</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Launch
open LumiAgent.app
```

---

## ✅ Verify It's Working

After running with any option above, you should see:

```
✅ LumiAgent launched successfully
📦 Bundle ID: com.lumiagent.app
✅ Database initialized at: ...
```

**And most importantly:**
- Click buttons → They respond
- Type in text fields → Text appears
- Use dropdowns → They work
- Everything is interactive!

---

## 🎯 Recommended: Option 1 (Launch Script)

The `./run_app.sh` script is the quickest way to get a working app right now.

**Try it:**
```bash
chmod +x run_app.sh  # Make executable (if needed)
./run_app.sh          # Launch!
```

You should see the app window with fully working UI! 🎉

---

## 🐛 Still Having Issues?

If UI is still locked after trying the above:

1. **Check the console output** - look for the bundle ID line
2. **Try restarting Xcode** completely
3. **Clean build folder** in Xcode: Product → Clean Build Folder (⇧⌘K)
4. **Check macOS permissions** - System Settings → Privacy & Security

---

**Bottom line:** Use `./run_app.sh` for instant working app! 🚀
