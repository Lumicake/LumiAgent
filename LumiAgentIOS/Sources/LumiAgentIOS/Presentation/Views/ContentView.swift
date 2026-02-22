//
//  ContentView.swift
//  LumiAgentIOS
//
//  Root tab bar for the iOS app.
//  Four tabs:
//    1. Device Control  — local brightness, volume, media, weather, messages
//    2. Mac Remote      — discover and control nearby macOS LumiAgent hosts
//    3. Shortcuts       — Siri/Shortcuts actions + keyboard shortcut reference
//    4. About           — build info and setup tips
//

import SwiftUI

// MARK: - Content View

public struct ContentView: View {

    @State private var mediaController = IOSMediaController.shared
    @State private var composeRequest: MessageComposeRequest?

    public init() {}

    public var body: some View {
        TabView {
            SystemControlView()
                .tabItem {
                    Label("Device", systemImage: "iphone.gen3")
                }

            MacRemoteView()
                .tabItem {
                    Label("Mac Remote", systemImage: "desktopcomputer")
                }

            ShortcutsIntegrationView()
                .tabItem {
                    Label("Shortcuts", systemImage: "square.grid.2x2.fill")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        // ── Hardware keyboard shortcuts (iPad + external keyboard) ─────────────
        // These work system-wide while the app is active.
        .onKeyPress(.space) { mediaController.togglePlayPause(); return .handled }
        .background(KeyboardShortcutsReceiver(mediaController: mediaController))
        // ── ComposeSMSIntent notification ──────────────────────────────────────
        .onReceive(NotificationCenter.default.publisher(for: .lumiComposeMessage)) { note in
            composeRequest = note.object as? MessageComposeRequest
        }
        .messageComposeSheet($composeRequest)
    }
}

// MARK: - About View

private struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("LumiAgent iOS") {
                    InfoRow(label: "Version", value: "1.0")
                    InfoRow(label: "iOS Minimum", value: "iOS 17")
                    InfoRow(label: "Build", value: buildDate)
                }

                Section("Device Control") {
                    FeatureRow(icon: "sun.max.fill", color: .yellow,
                               title: "Brightness",
                               detail: "Read and write screen brightness via UIScreen API")
                    FeatureRow(icon: "speaker.wave.2.fill", color: .blue,
                               title: "Volume",
                               detail: "System volume via MPVolumeView (App Store safe)")
                    FeatureRow(icon: "music.note", color: .purple,
                               title: "Music",
                               detail: "Control Apple Music / Now Playing via MediaPlayer")
                    FeatureRow(icon: "cloud.sun.fill", color: .cyan,
                               title: "Weather",
                               detail: "Real-time weather via Open-Meteo (free, no API key)")
                    FeatureRow(icon: "message.fill", color: .green,
                               title: "Messages & SMS",
                               detail: "Compose via system sheet; iOS sandbox prevents reading")
                }

                Section("Mac Remote") {
                    FeatureRow(icon: "wifi.circle", color: .indigo,
                               title: "Bonjour Discovery",
                               detail: "Auto-detects macOS LumiAgent on the same Wi-Fi")
                    FeatureRow(icon: "desktopcomputer", color: .orange,
                               title: "Full Mac Control",
                               detail: "Brightness, volume, media, screenshot, keyboard, apps")
                    FeatureRow(icon: "applescript", color: .teal,
                               title: "AppleScript & Shell",
                               detail: "Run arbitrary scripts on your Mac remotely")
                }

                Section("Setup — Mac Remote") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To enable Mac Remote Control:")
                            .font(.headline)
                        Text("1. Build and run LumiAgent on your Mac.")
                        Text("2. Both devices must be on the same Wi-Fi network.")
                        Text("3. The Mac app auto-starts a Bonjour-advertised server on port 47285.")
                        Text("4. Tap the Mac Remote tab and select your Mac from the list.")
                    }
                    .font(.callout)
                    .padding(.vertical, 4)
                }

                Section("Info.plist Requirements") {
                    PlistRow(key: "NSLocalNetworkUsageDescription",
                             note: "Required for Mac discovery")
                    PlistRow(key: "NSBonjourServices: _lumiagent._tcp",
                             note: "Required for Bonjour browsing")
                    PlistRow(key: "NSLocationWhenInUseUsageDescription",
                             note: "Required for weather location")
                }
            }
            .navigationTitle("About LumiAgent iOS")
        }
    }

    private var buildDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: Date())
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct PlistRow: View {
    let key: String
    let note: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key).font(.system(.caption, design: .monospaced))
            Text(note).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Hardware Keyboard Shortcuts Receiver

/// UIViewRepresentable that installs UIKeyCommands for the full command set.
/// SwiftUI's `.keyboardShortcut()` requires a focusable Button, which isn't
/// always present. UIKeyCommand works unconditionally on iPad with a keyboard.
struct KeyboardShortcutsReceiver: UIViewRepresentable {
    let mediaController: IOSMediaController

    func makeUIView(context: Context) -> KeyCommandView {
        let view = KeyCommandView(mediaController: mediaController)
        return view
    }

    func updateUIView(_ uiView: KeyCommandView, context: Context) {}
}

final class KeyCommandView: UIView {
    private let mediaController: IOSMediaController

    init(mediaController: IOSMediaController) {
        self.mediaController = mediaController
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        [
            // Media
            cmd(.rightArrow, modifiers: .command, title: "Next Track") { [weak self] in
                self?.mediaController.nextTrack()
            },
            cmd(.leftArrow,  modifiers: .command, title: "Previous Track") { [weak self] in
                self?.mediaController.previousTrack()
            },
            // Volume
            cmd(.upArrow,   modifiers: .command, title: "Volume Up") { [weak self] in
                self?.mediaController.increaseVolume()
            },
            cmd(.downArrow, modifiers: .command, title: "Volume Down") { [weak self] in
                self?.mediaController.decreaseVolume()
            },
            // Brightness
            cmd(.upArrow,   modifiers: [.command, .alternate], title: "Brightness Up") {
                Task { @MainActor in await IOSBrightnessController.shared.increaseBrightness() }
            },
            cmd(.downArrow, modifiers: [.command, .alternate], title: "Brightness Down") {
                Task { @MainActor in await IOSBrightnessController.shared.decreaseBrightness() }
            },
        ]
    }

    private func cmd(
        _ key: UIKeyCommand.inputType,
        modifiers: UIKeyModifierFlags,
        title: String,
        action block: @escaping () -> Void
    ) -> UIKeyCommand {
        let sel = makeSelector(for: block)
        return UIKeyCommand(
            title: title,
            image: nil,
            action: sel,
            input: key,
            modifierFlags: modifiers,
            propertyList: nil
        )
    }
}

// UIKeyCommand.inputType alias for string literals
extension UIKeyCommand {
    typealias inputType = String
}

// Lightweight selector factory — each call creates a unique ObjC method on KeyCommandView.
private var blockStore: [String: () -> Void] = [:]
private func makeSelector(for block: @escaping () -> Void) -> Selector {
    let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    let selName = "lumiKey_\(uuid)"
    blockStore[selName] = block
    let imp: IMP = imp_implementationWithBlock({ _ in blockStore[selName]?() } as @convention(block) (AnyObject) -> Void)
    let sel = NSSelectorFromString(selName)
    class_addMethod(KeyCommandView.self, sel, imp, "v@:")
    return sel
}
