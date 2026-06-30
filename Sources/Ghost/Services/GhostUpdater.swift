import Foundation
import Sparkle

@MainActor
final class GhostUpdater {
    static let shared = GhostUpdater()

    private let updaterController: SPUStandardUpdaterController

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
