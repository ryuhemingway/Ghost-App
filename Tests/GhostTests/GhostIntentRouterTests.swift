import Foundation
import Testing
@testable import Ghost

@Suite("Ghost intent routing")
struct GhostIntentRouterTests {
    private let router = GhostIntentRouter()
    private let workspaceRoot = URL(fileURLWithPath: NSHomeDirectory())

    @Test("Simple factual capital questions stay on answer route")
    func factualCapitalQuestionRoutesAsAnswer() {
        let intent = router.detect(
            prompt: "what is the capital of France?",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .answer)
    }

    @Test("Historical when questions do not route to automation")
    func historicalWhenQuestionRoutesAsAnswer() {
        let intent = router.detect(
            prompt: "What is the significance of Sensoji temple and when was it made?",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .answer)
    }

    @Test("Reminder prompts still route to automation")
    func reminderPromptRoutesAsAutomation() {
        let intent = router.detect(
            prompt: "Remind me every day to check the report",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .automation)
    }

    @Test("Debugging SwiftUI still routes to debugging")
    func swiftUIDebugPromptRoutesAsDebugging() {
        let intent = router.detect(
            prompt: "debug this SwiftUI view",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .debugging)
    }

    @Test("Implementation prompts still route to coding")
    func swiftUIImplementationPromptRoutesAsCoding() {
        let intent = router.detect(
            prompt: "implement a SwiftUI component",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .coding)
    }
}
