import AppKit

@MainActor
enum AppWindowFactory {
    static func make(contentViewController: NSViewController) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 338),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Leanwave"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isRestorable = false
        window.sharingType = .readOnly
        window.contentViewController = contentViewController
        window.setContentSize(NSSize(width: 540, height: 338))
        window.minSize = window.frame.size
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        return window
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var playerViewController: PlayerViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = PlayerViewController()
        let window = AppWindowFactory.make(contentViewController: controller)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        playerViewController = controller
        controller.fetchFromChrome(showErrors: false)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        playerViewController?.stopPlayback()
    }
}
