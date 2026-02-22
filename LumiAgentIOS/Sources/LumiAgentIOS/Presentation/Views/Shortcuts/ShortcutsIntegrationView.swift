//
//  ShortcutsIntegrationView.swift
//  LumiAgentIOS
//
//  "Shortcuts" tab — three sections:
//    1. App Shortcuts  – all LumiAgent Siri/Shortcuts-registered actions
//    2. Run a Shortcut – deep-link into the Shortcuts app to run any user workflow
//    3. Keyboard       – hardware-keyboard shortcut reference for iPad
//

import SwiftUI
import AppIntents

// MARK: - Shortcuts Integration View

public struct ShortcutsIntegrationView: View {

    @State private var runShortcutName: String = ""
    @State private var showRunField: Bool = false
    @State private var runResult: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                appShortcutsSection
                runShortcutSection
                keyboardSection
                infoSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Shortcuts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openShortcutsApp()
                    } label: {
                        Label("Open Shortcuts", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var appShortcutsSection: some View {
        Section {
            ForEach(ShortcutAction.allCases) { action in
                ShortcutActionRow(action: action)
            }
        } header: {
            Text("Available Actions")
        } footer: {
            Text("All actions appear automatically in the Shortcuts app under \"LumiAgent\". Tap \"Open Shortcuts\" above to build workflows.")
        }
    }

    private var runShortcutSection: some View {
        Section {
            if showRunField {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Shortcut name", text: $runShortcutName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    HStack {
                        Button("Run") { runShortcut(named: runShortcutName) }
                            .buttonStyle(.borderedProminent)
                            .disabled(runShortcutName.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Cancel", role: .cancel) {
                            showRunField = false
                            runShortcutName = ""
                            runResult = nil
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let result = runResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    showRunField = true
                } label: {
                    Label("Run a Shortcut by Name", systemImage: "play.circle.fill")
                }
            }
        } header: {
            Text("Run Shortcut")
        } footer: {
            Text("Opens the Shortcuts app and runs the named workflow. The shortcut must exist in the user's library.")
        }
    }

    private var keyboardSection: some View {
        Section {
            ForEach(KeyboardShortcutEntry.allEntries) { entry in
                KeyboardShortcutRow(entry: entry)
            }
        } header: {
            Text("Hardware Keyboard (iPad)")
        } footer: {
            Text("These shortcuts work when a physical keyboard is connected to your iPad.")
        }
    }

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Add to Siri", systemImage: "mic.fill")
                    .font(.headline)
                Text("Say \"Hey Siri, play music with LumiAgent\" or any phrase shown above to trigger an action without opening the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Siri Integration")
        }
    }

    // MARK: - Actions

    private func runShortcut(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://run-shortcut?name=\(encoded)") else {
            runResult = "Invalid shortcut name."
            return
        }
        UIApplication.shared.open(url) { success in
            runResult = success ? "Launched in Shortcuts app." : "Could not open Shortcuts app."
        }
    }

    private func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Shortcut Action Row

private struct ShortcutActionRow: View {
    let action: ShortcutAction

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(action.color.gradient)
                    .frame(width: 36, height: 36)
                Image(systemName: action.systemImage)
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(action.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(action.category)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(action.color.opacity(0.12))
                .foregroundStyle(action.color)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Keyboard Shortcut Row

private struct KeyboardShortcutRow: View {
    let entry: KeyboardShortcutEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.action)
                    .font(.subheadline)
                Text(entry.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.keys)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Data Models

/// All LumiAgent actions available in the Shortcuts app.
enum ShortcutAction: String, CaseIterable, Identifiable {
    // Device control
    case setBrightness
    case getBrightness
    case setVolume
    case increaseVolume
    case decreaseVolume
    // Media
    case playMusic
    case pauseMusic
    case togglePlayPause
    case nextTrack
    case previousTrack
    case getNowPlaying
    // Weather
    case getWeather
    // Messages
    case composeSMS
    // Mac Remote
    case macSetBrightness
    case macSetVolume
    case macToggleMedia
    case macScreenshot
    case macOpenApp
    case macRunAppleScript
    case macTypeText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .setBrightness:    return "Set Brightness"
        case .getBrightness:    return "Get Brightness"
        case .setVolume:        return "Set Volume"
        case .increaseVolume:   return "Increase Volume"
        case .decreaseVolume:   return "Decrease Volume"
        case .playMusic:        return "Play Music"
        case .pauseMusic:       return "Pause Music"
        case .togglePlayPause:  return "Toggle Play/Pause"
        case .nextTrack:        return "Next Track"
        case .previousTrack:    return "Previous Track"
        case .getNowPlaying:    return "Get Now Playing"
        case .getWeather:       return "Get Weather"
        case .composeSMS:       return "Compose Message"
        case .macSetBrightness: return "Set Mac Brightness"
        case .macSetVolume:     return "Set Mac Volume"
        case .macToggleMedia:   return "Mac Play/Pause"
        case .macScreenshot:    return "Mac Screenshot"
        case .macOpenApp:       return "Open App on Mac"
        case .macRunAppleScript:return "Run AppleScript on Mac"
        case .macTypeText:      return "Type Text on Mac"
        }
    }

    var description: String {
        switch self {
        case .setBrightness:    return "Set iPhone/iPad screen brightness (0–100)"
        case .getBrightness:    return "Returns current brightness as a number"
        case .setVolume:        return "Set device output volume (0–100)"
        case .increaseVolume:   return "Raise volume by 10%"
        case .decreaseVolume:   return "Lower volume by 10%"
        case .playMusic:        return "Start Apple Music playback"
        case .pauseMusic:       return "Pause Apple Music"
        case .togglePlayPause:  return "Toggle between play and pause"
        case .nextTrack:        return "Skip to the next song"
        case .previousTrack:    return "Go back one track"
        case .getNowPlaying:    return "Returns current track title and artist"
        case .getWeather:       return "Returns weather at your current location"
        case .composeSMS:       return "Open SMS/iMessage compose sheet"
        case .macSetBrightness: return "Set connected Mac display brightness"
        case .macSetVolume:     return "Set connected Mac output volume"
        case .macToggleMedia:   return "Play/pause Music on connected Mac"
        case .macScreenshot:    return "Take a screenshot of connected Mac"
        case .macOpenApp:       return "Open an app by name on connected Mac"
        case .macRunAppleScript:return "Execute AppleScript on connected Mac"
        case .macTypeText:      return "Type text into focused Mac app"
        }
    }

    var category: String {
        switch self {
        case .setBrightness, .getBrightness,
             .setVolume, .increaseVolume, .decreaseVolume:
            return "Device"
        case .playMusic, .pauseMusic, .togglePlayPause,
             .nextTrack, .previousTrack, .getNowPlaying:
            return "Media"
        case .getWeather:
            return "Weather"
        case .composeSMS:
            return "Messages"
        default:
            return "Mac"
        }
    }

    var systemImage: String {
        switch self {
        case .setBrightness, .getBrightness:    return "sun.max.fill"
        case .setVolume, .increaseVolume:       return "speaker.wave.2.fill"
        case .decreaseVolume:                   return "speaker.wave.1.fill"
        case .playMusic:                        return "play.fill"
        case .pauseMusic:                       return "pause.fill"
        case .togglePlayPause:                  return "playpause.fill"
        case .nextTrack:                        return "forward.fill"
        case .previousTrack:                    return "backward.fill"
        case .getNowPlaying:                    return "music.note"
        case .getWeather:                       return "cloud.sun.fill"
        case .composeSMS:                       return "message.fill"
        case .macSetBrightness:                 return "sun.max"
        case .macSetVolume:                     return "speaker.wave.2"
        case .macToggleMedia:                   return "playpause"
        case .macScreenshot:                    return "camera.viewfinder"
        case .macOpenApp:                       return "app.badge"
        case .macRunAppleScript:                return "applescript"
        case .macTypeText:                      return "keyboard"
        }
    }

    var color: Color {
        switch category {
        case "Device":   return .blue
        case "Media":    return .purple
        case "Weather":  return .cyan
        case "Messages": return .green
        default:         return .orange
        }
    }
}

/// iPad hardware keyboard shortcuts reference.
struct KeyboardShortcutEntry: Identifiable {
    let id = UUID()
    let action: String
    let description: String
    let keys: String

    static let allEntries: [KeyboardShortcutEntry] = [
        .init(action: "Play/Pause",       description: "Toggle music playback",        keys: "Space"),
        .init(action: "Next Track",        description: "Skip to next song",            keys: "⌘→"),
        .init(action: "Previous Track",    description: "Go back one track",            keys: "⌘←"),
        .init(action: "Volume Up",         description: "Increase volume by 10%",       keys: "⌘↑"),
        .init(action: "Volume Down",       description: "Decrease volume by 10%",       keys: "⌘↓"),
        .init(action: "Brightness Up",     description: "Increase brightness by 10%",   keys: "⌥⌘↑"),
        .init(action: "Brightness Down",   description: "Decrease brightness by 10%",   keys: "⌥⌘↓"),
        .init(action: "Refresh Weather",   description: "Reload weather data",          keys: "⌘R"),
        .init(action: "Mac Screenshot",    description: "Take remote Mac screenshot",   keys: "⌘⇧S"),
        .init(action: "Connect/Discover",  description: "Scan for nearby Macs",         keys: "⌘K"),
    ]
}
