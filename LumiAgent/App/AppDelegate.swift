//
//  AppDelegate.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ LumiAgent launched successfully")
        print("📦 Bundle ID: \(Bundle.main.bundleIdentifier ?? "not set")")

        // Configure app
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Start the iOS remote-control server.
        // Advertises on Bonjour (_lumiagent._tcp, port 47285) so the iOS
        // LumiAgent app can discover and connect to this Mac automatically.
        Task { @MainActor in
            MacRemoteServer.shared.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 LumiAgent shutting down")
        Task { @MainActor in MacRemoteServer.shared.stop() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even if all windows closed
        return false
    }
}
