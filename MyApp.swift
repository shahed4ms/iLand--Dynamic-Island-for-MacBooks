
import SwiftUI
import AppKit

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var islandWindowController: IslandWindowController?
    private var settingsWindow: NSWindow?
    private var settingsStatusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep iLand as a menu-bar utility app.
        NSApp.setActivationPolicy(.accessory)

        // Create and show the floating island.
        let controller = IslandWindowController()
        islandWindowController = controller
        controller.showWindow()

        // Add the Settings gear to the right side of the menu bar.
        installSettingsMenuBarIcon()
    }

    private func installSettingsMenuBarIcon() {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "gearshape",
                accessibilityDescription: "iLand Settings"
            )

            button.toolTip = "iLand Settings"
            button.target = self
            button.action = #selector(openSettings)
        }

        settingsStatusItem = item
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: 460,
                    height: 420
                ),
                styleMask: [
                    .titled,
                    .closable,
                    .miniaturizable
                ],
                backing: .buffered,
                defer: false
            )

            window.title = "iLand Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: SettingsView()
            )

            settingsWindow = window
        }

        guard let settingsWindow else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
    }
}
