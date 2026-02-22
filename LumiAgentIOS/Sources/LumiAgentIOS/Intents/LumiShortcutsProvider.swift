//
//  LumiShortcutsProvider.swift
//  LumiAgentIOS
//
//  Registers predefined App Shortcuts so users can trigger them by
//  voice ("Hey Siri, set brightness to 80 in LumiAgent") or via the
//  Shortcuts app without building a workflow first.
//
//  The phrases listed here appear in Settings → Siri & Search, and
//  the Shortcuts app shows them under "LumiAgent" → "Starter Shortcuts".
//
//  Rules:
//    • Up to 10 App Shortcuts per app.
//    • Each shortcut may have up to 5 phrase variants.
//    • At least one phrase must include \(.applicationName).
//    • Parameter placeholders use \(.$paramName) syntax.
//
//  Requires iOS 16.4+ (AppShortcutsProvider GA). We target iOS 17+ so all good.
//

import AppIntents

// MARK: - App Shortcuts Provider

struct LumiShortcutsProvider: AppShortcutsProvider {

    /// Tint color for shortcuts in the Shortcuts app (purple-ish).
    static var shortcutTileColor: ShortcutTileColor { .purple }

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {

        // 1. Set brightness
        AppShortcut(
            intent: SetBrightnessIntent(),
            phrases: [
                "Set brightness to \(\.$level) in \(.applicationName)",
                "Dim screen to \(\.$level) with \(.applicationName)",
                "\(.applicationName) brightness \(\.$level)"
            ],
            shortTitle: "Set Brightness",
            systemImageName: "sun.max.fill"
        )

        // 2. Set volume
        AppShortcut(
            intent: SetVolumeIntent(),
            phrases: [
                "Set volume to \(\.$level) in \(.applicationName)",
                "Volume \(\.$level) with \(.applicationName)",
                "\(.applicationName) set volume \(\.$level)"
            ],
            shortTitle: "Set Volume",
            systemImageName: "speaker.wave.2.fill"
        )

        // 3. Play music
        AppShortcut(
            intent: PlayMusicIntent(),
            phrases: [
                "Play music with \(.applicationName)",
                "Start playing with \(.applicationName)",
                "\(.applicationName) play"
            ],
            shortTitle: "Play Music",
            systemImageName: "play.fill"
        )

        // 4. Pause music
        AppShortcut(
            intent: PauseMusicIntent(),
            phrases: [
                "Pause music with \(.applicationName)",
                "Stop playing with \(.applicationName)",
                "\(.applicationName) pause"
            ],
            shortTitle: "Pause Music",
            systemImageName: "pause.fill"
        )

        // 5. Next track
        AppShortcut(
            intent: NextTrackIntent(),
            phrases: [
                "Skip song with \(.applicationName)",
                "Next track with \(.applicationName)",
                "\(.applicationName) next song"
            ],
            shortTitle: "Next Track",
            systemImageName: "forward.fill"
        )

        // 6. Get now playing
        AppShortcut(
            intent: GetNowPlayingIntent(),
            phrases: [
                "What's playing with \(.applicationName)",
                "What song is this in \(.applicationName)",
                "\(.applicationName) now playing"
            ],
            shortTitle: "Now Playing",
            systemImageName: "music.note"
        )

        // 7. Get weather
        AppShortcut(
            intent: GetWeatherIntent(),
            phrases: [
                "What's the weather with \(.applicationName)",
                "Get weather from \(.applicationName)",
                "\(.applicationName) weather"
            ],
            shortTitle: "Get Weather",
            systemImageName: "cloud.sun.fill"
        )

        // 8. Mac play/pause
        AppShortcut(
            intent: MacToggleMediaIntent(),
            phrases: [
                "Play pause Mac with \(.applicationName)",
                "Toggle Mac music using \(.applicationName)",
                "\(.applicationName) Mac play pause"
            ],
            shortTitle: "Mac Play/Pause",
            systemImageName: "desktopcomputer"
        )

        // 9. Mac screenshot
        AppShortcut(
            intent: MacScreenshotIntent(),
            phrases: [
                "Screenshot Mac with \(.applicationName)",
                "Take Mac screenshot using \(.applicationName)",
                "\(.applicationName) Mac screenshot"
            ],
            shortTitle: "Mac Screenshot",
            systemImageName: "camera.viewfinder"
        )

        // 10. Open app on Mac
        AppShortcut(
            intent: MacOpenAppIntent(),
            phrases: [
                "Open \(\.$appName) on Mac with \(.applicationName)",
                "Launch \(\.$appName) on Mac using \(.applicationName)",
                "\(.applicationName) open Mac app \(\.$appName)"
            ],
            shortTitle: "Open App on Mac",
            systemImageName: "app.badge"
        )
    }
}
