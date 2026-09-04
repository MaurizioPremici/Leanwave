import AppKit

@MainActor
enum AppWindowFactory {

    static func make(contentViewController: NSViewController) -> NSWindow {

        let size = NSSize(width: 720, height: 250)

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: size.width,
                height: size.height
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "Leanwave"

        // Titolo macOS invisibile
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        // Finestra trasparente
        window.isOpaque = false
        window.backgroundColor = .clear

        // Permette di trascinare la finestra cliccando sullo sfondo
        window.isMovableByWindowBackground = true

        // Player sempre sopra
        window.level = .floating

        window.hasShadow = true
        window.isRestorable = false
        window.sharingType = .readOnly

        window.contentViewController = contentViewController

        window.setContentSize(size)

        // Dimensione fissa
        window.minSize = window.frame.size
        window.maxSize = window.frame.size

        // Nascondiamo i normali pulsanti macOS
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
