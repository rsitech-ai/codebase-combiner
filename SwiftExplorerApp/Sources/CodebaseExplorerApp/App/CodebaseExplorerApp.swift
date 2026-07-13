import AppKit
import SwiftUI

@main
struct CodebaseExplorerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController.live()

    var body: some Scene {
        WindowGroup("Codebase Combiner") {
            ContentView(controller: controller)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            AppCommands(controller: controller)
        }

        Settings {
            SettingsView(preferences: controller.preferences)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        false
    }

    func application(_: NSApplication, shouldSaveSecureApplicationState _: NSCoder) -> Bool {
        false
    }

    func application(_: NSApplication, shouldRestoreSecureApplicationState _: NSCoder) -> Bool {
        false
    }

    func application(_: NSApplication, shouldSaveApplicationState _: NSCoder) -> Bool {
        false
    }

    func application(_: NSApplication, shouldRestoreApplicationState _: NSCoder) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        AppLog.lifecycle.info("Application finished launching")
        DispatchQueue.main.async { self.disableWindowRestoration() }
        DispatchQueue.main.async { self.recenterOffscreenWindowsIfNeeded() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.disableWindowRestoration() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.recenterOffscreenWindowsIfNeeded() }
    }

    @MainActor
    private func disableWindowRestoration() {
        for window in NSApp.windows {
            window.isRestorable = false
            window.restorationClass = nil
            window.disableSnapshotRestoration()
        }
    }

    @MainActor
    private func recenterOffscreenWindowsIfNeeded() {
        for window in NSApp.windows where window.isVisible {
            guard !window.frame.isEmpty else { continue }
            let isVisible = NSScreen.screens.contains { $0.visibleFrame.intersects(window.frame) }
            if !isVisible, let screen = NSScreen.main {
                window.setFrameOrigin(CGPoint(
                    x: screen.visibleFrame.midX - window.frame.width / 2,
                    y: screen.visibleFrame.midY - window.frame.height / 2
                ))
            }
        }
    }
}
