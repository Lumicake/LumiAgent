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
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 LumiAgent shutting down")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even if all windows closed
        return false
    }
}
