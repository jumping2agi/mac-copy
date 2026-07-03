import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Build the menu bar item.
        statusBarController = StatusBarController()

        // Begin tracking the clipboard for history.
        ClipboardHistoryManager.shared.start()

        // Keep the app alive in the background; it has no Dock icon
        // (LSUIElement = true in Info.plist), so it lives only in the menu bar.
        NSApp.activate(ignoringOtherApps: false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardHistoryManager.shared.stop()
    }

    /// Prevent the app from terminating when the (hidden) main window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
