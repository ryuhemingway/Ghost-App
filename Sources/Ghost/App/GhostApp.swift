import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: GhostStatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistry.registerFonts()
        applyApplicationIcon()
        NSApp.setActivationPolicy(.accessory)
        _ = GhostUpdater.shared

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

    private func applyApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "Ghost", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL)
        else { return }

        NSApp.applicationIconImage = icon
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
