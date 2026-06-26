import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistry.registerFonts()
        NSApp.setActivationPolicy(.accessory)

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
    @State private var store = GhostConversationStore(
        ghostClient: GhostClient(),
        speechRecognizer: SpeechTranscriber()
    )

    var body: some Scene {
        MenuBarExtra {
            GhostPanelView(store: store)
        } label: {
            Image(nsImage: GhostMenuBarIcon.make())
        }
        .menuBarExtraStyle(.window)
    }
}
