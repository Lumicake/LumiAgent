//
//  LumiAppIntents.swift
//  LumiAgentIOS
//
//  App Intents exposed to the iOS Shortcuts app and Siri.
//  Once the app is installed, every intent here appears automatically
//  under "LumiAgent" in the Shortcuts action library.
//
//  Siri phrases are registered separately in LumiShortcutsProvider.swift.
//
//  Requires: iOS 16+  (all intents are available; we target iOS 17+)
//  Framework: AppIntents (no additional entitlement required)
//

import AppIntents
import UIKit
import Foundation

// MARK: - Brightness

/// Set local iPhone/iPad screen brightness.
struct SetBrightnessIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Brightness"
    static var description = IntentDescription(
        "Set the iPhone or iPad screen brightness.",
        categoryName: "Device Control"
    )

    @Parameter(title: "Brightness Level", description: "0 to 100 percent.",
               inclusiveRange: (0, 100))
    var level: Int

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        await MainActor.run {
            UIScreen.main.brightness = CGFloat(level) / 100.0
        }
        return .result(value: level)
    }
}

/// Get the current screen brightness.
struct GetBrightnessIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Brightness"
    static var description = IntentDescription(
        "Returns the current screen brightness as a number 0–100.",
        categoryName: "Device Control"
    )

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let b = await MainActor.run { Double(UIScreen.main.brightness) }
        return .result(value: Int(b * 100))
    }
}

// MARK: - Volume

/// Set local system output volume.
struct SetVolumeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Volume"
    static var description = IntentDescription(
        "Set the device output volume.",
        categoryName: "Device Control"
    )

    @Parameter(title: "Volume Level", description: "0 to 100 percent.",
               inclusiveRange: (0, 100))
    var level: Int

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        await MainActor.run { IOSMediaController.shared.setVolume(Double(level) / 100.0) }
        return .result(value: level)
    }
}

/// Increase volume by a step.
struct IncreaseVolumeIntent: AppIntent {
    static var title: LocalizedStringResource = "Increase Volume"
    static var description = IntentDescription("Increase device volume by 10%.", categoryName: "Device Control")

    func perform() async throws -> some IntentResult {
        await MainActor.run { IOSMediaController.shared.increaseVolume() }
        return .result()
    }
}

/// Decrease volume by a step.
struct DecreaseVolumeIntent: AppIntent {
    static var title: LocalizedStringResource = "Decrease Volume"
    static var description = IntentDescription("Decrease device volume by 10%.", categoryName: "Device Control")

    func perform() async throws -> some IntentResult {
        await MainActor.run { IOSMediaController.shared.decreaseVolume() }
        return .result()
    }
}

// MARK: - Media Playback

/// Start music playback.
struct PlayMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Music"
    static var description = IntentDescription(
        "Start or resume music playback in Apple Music.",
        categoryName: "Media"
    )

    func perform() async throws -> some IntentResult {
        await MainActor.run { IOSMediaController.shared.play() }
        return .result()
    }
}

/// Pause music playback.
struct PauseMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Music"
    static var description = IntentDescription(
        "Pause music playback.",
        categoryName: "Media"
    )

    func perform() async throws -> some IntentResult {
        await MainActor.run { IOSMediaController.shared.pause() }
        return .result()
    }
}

/// Toggle play/pause.
struct TogglePlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Play/Pause"
    static var description = IntentDescription(
        "Toggle music playback between playing and paused.",
        categoryName: "Media"
    )

    func perform() async throws -> some IntentResult {
        await MainActor.run { IOSMediaController.shared.togglePlayPause() }
        return .result()
    }
}

/// Skip to the next track.
struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    static var description = IntentDescription("Skip to the next song.", categoryName: "Media")

    func perform() async throws -> some IntentResult {
        await MainActor.run { IOSMediaController.shared.nextTrack() }
        return .result()
    }
}

/// Go back to the previous track.
struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    static var description = IntentDescription("Go back to the previous song.", categoryName: "Media")

    func perform() async throws -> some IntentResult {
        await MainActor.run { IOSMediaController.shared.previousTrack() }
        return .result()
    }
}

/// Get current Now Playing info as a string.
struct GetNowPlayingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Now Playing"
    static var description = IntentDescription(
        "Returns the title and artist of the currently playing song.",
        categoryName: "Media"
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let (title, artist) = await MainActor.run {
            (IOSMediaController.shared.nowPlayingTitle, IOSMediaController.shared.nowPlayingArtist)
        }
        let result: String
        if let t = title {
            result = artist.map { "\(t) — \($0)" } ?? t
        } else {
            result = "Nothing is playing."
        }
        return .result(value: result)
    }
}

// MARK: - Weather

/// Get current weather conditions.
struct GetWeatherIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Weather"
    static var description = IntentDescription(
        "Returns current weather conditions at your location.",
        categoryName: "Weather"
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Trigger a refresh and wait up to 10 s for it to complete.
        await MainActor.run { IOSWeatherController.shared.refresh() }

        var attempts = 0
        while attempts < 20 {
            try await Task.sleep(nanoseconds: 500_000_000)
            let (cond, temp, loc, loading) = await MainActor.run {
                (IOSWeatherController.shared.condition,
                 IOSWeatherController.shared.temperature,
                 IOSWeatherController.shared.locationName,
                 IOSWeatherController.shared.isLoading)
            }
            if !loading {
                let locationStr = loc.isEmpty ? "" : " in \(loc)"
                return .result(value: "\(cond)\(locationStr), \(temp)")
            }
            attempts += 1
        }
        throw AppIntentError.weatherTimeout
    }
}

enum AppIntentError: Error, CustomLocalizedStringResourceConvertible {
    case weatherTimeout
    case noMacConnected
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .weatherTimeout:        return "Weather data not available. Try again."
        case .noMacConnected:        return "No Mac is connected. Open LumiAgent and connect to your Mac first."
        case .commandFailed(let m):  return "\(m)"
        }
    }
}

// MARK: - Messages

/// Compose an SMS / iMessage (opens system compose sheet).
struct ComposeSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "Compose Message"
    static var description = IntentDescription(
        "Open the compose sheet to send an SMS or iMessage.",
        categoryName: "Messages",
        searchKeywords: ["sms", "imessage", "text", "message"]
    )
    static var openAppWhenRun: Bool = true  // must open app to show the sheet

    @Parameter(title: "Recipient", description: "Phone number or email address.")
    var recipient: String

    @Parameter(title: "Message Body", description: "Text of the message.")
    var body: String

    func perform() async throws -> some IntentResult {
        // Posting to NotificationCenter lets the running app open the sheet.
        await MainActor.run {
            NotificationCenter.default.post(
                name: .lumiComposeMessage,
                object: MessageComposeRequest(recipients: [recipient], body: body)
            )
        }
        return .result()
    }
}

// MARK: - Mac Remote Intents

/// Set the connected Mac's screen brightness remotely.
struct MacSetBrightnessIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Mac Brightness"
    static var description = IntentDescription(
        "Set the screen brightness on a connected Mac.",
        categoryName: "Mac Remote"
    )

    @Parameter(title: "Brightness Level", description: "0.0 to 1.0", inclusiveRange: (0.0, 1.0))
    var level: Double

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await withMacClient { try await $0.setBrightness(level) }
        return .result(value: response.result)
    }
}

/// Set the connected Mac's volume remotely.
struct MacSetVolumeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Mac Volume"
    static var description = IntentDescription(
        "Set the output volume on a connected Mac.",
        categoryName: "Mac Remote"
    )

    @Parameter(title: "Volume Level", description: "0 to 100 percent.",
               inclusiveRange: (0, 100))
    var level: Int

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await withMacClient { try await $0.setVolume(Double(level) / 100.0) }
        return .result(value: response.result)
    }
}

/// Toggle Mac media play/pause remotely.
struct MacToggleMediaIntent: AppIntent {
    static var title: LocalizedStringResource = "Mac Play/Pause"
    static var description = IntentDescription(
        "Toggle music playback on the connected Mac.",
        categoryName: "Mac Remote"
    )

    func perform() async throws -> some IntentResult {
        _ = try await withMacClient { try await $0.send(RemoteCommand(commandType: .mediaToggle)) }
        return .result()
    }
}

/// Take a screenshot of the connected Mac.
struct MacScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Mac Screenshot"
    static var description = IntentDescription(
        "Take a screenshot of the connected Mac's screen.",
        categoryName: "Mac Remote"
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await withMacClient { try await $0.screenshot() }
        return .result(value: response.success ? "Screenshot captured." : (response.error ?? "Failed"))
    }
}

/// Open an application on the connected Mac.
struct MacOpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open App on Mac"
    static var description = IntentDescription(
        "Open an application by name on the connected Mac.",
        categoryName: "Mac Remote"
    )

    @Parameter(title: "Application Name", description: "e.g. Safari, Finder, Xcode")
    var appName: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await withMacClient { try await $0.openApplication(appName) }
        return .result(value: response.result)
    }
}

/// Run an AppleScript on the connected Mac.
struct MacRunAppleScriptIntent: AppIntent {
    static var title: LocalizedStringResource = "Run AppleScript on Mac"
    static var description = IntentDescription(
        "Execute an AppleScript on the connected Mac and return the result.",
        categoryName: "Mac Remote"
    )

    @Parameter(title: "Script", description: "AppleScript source code to execute.")
    var script: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await withMacClient { try await $0.runAppleScript(script) }
        return .result(value: response.result)
    }
}

/// Type text on the connected Mac.
struct MacTypeTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Type Text on Mac"
    static var description = IntentDescription(
        "Type text into the currently focused app on the connected Mac.",
        categoryName: "Mac Remote"
    )

    @Parameter(title: "Text", description: "Text to type on the Mac.")
    var text: String

    func perform() async throws -> some IntentResult {
        _ = try await withMacClient { try await $0.typeText(text) }
        return .result()
    }
}

// MARK: - Mac client helper

/// Retrieves the shared MacRemoteClient; throws if not connected.
private func withMacClient<T>(
    _ block: (MacRemoteClient) async throws -> T
) async throws -> T {
    let client = await MainActor.run { MacRemoteClient.shared }
    guard await MainActor.run(resultType: Bool.self, body: { client.state.isConnected }) else {
        throw AppIntentError.noMacConnected
    }
    return try await block(client)
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted by ComposeSMSIntent to ask the running app to open the compose sheet.
    static let lumiComposeMessage = Notification.Name("com.lumiagent.ios.composeMessage")
}
