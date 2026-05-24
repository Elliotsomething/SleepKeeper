import AppKit
import SwiftUI

@main
struct SleepKeeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = SleepKeeperAppState()

    var body: some Scene {
        WindowGroup("SleepKeeper", id: "main") {
            ContentView(model: appState.model)
                .frame(minWidth: 460, minHeight: 360)
        }
        .commands {
            CommandMenu("SleepKeeper") {
                Button(appState.model.isEnabled ? "Turn Off" : "Turn On") {
                    appState.model.toggle()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
