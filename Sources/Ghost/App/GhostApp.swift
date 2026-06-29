import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: GhostStatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistry.registerFonts()
        NSApp.setActivationPolicy(.accessory)

        let store = GhostConversationStore(
            ghostClient: GhostClient(),
            speechRecognizer: SpeechTranscriber()
        )

        let controller = GhostStatusBarController(store: store)
        controller.install()
        self.statusBarController = controller

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option), event.keyCode == 49 {
                NotificationCenter.default.post(name: .ghostTogglePanel, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let ghostTogglePanel = Notification.Name("ghostTogglePanel")
}

@main
struct GhostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}