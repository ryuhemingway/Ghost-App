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

    @Test("Response composition with ACM URL stays in chat")
    func responseCompositionWithACMURLStaysInChat() {
        let prompt = """
        write what my response should be: Prompt: Algorithms and Data Structures in Cybersecurity and Networking.
        Use resources and include ACM format citations. Retrieved from https://www.acm.org/publications/authors/reference-formatting
        """

        let intent = router.detect(
            prompt: prompt,
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .research || intent.kind == .answer)
        #expect(intent.requestedFilename == nil)
        #expect(intent.inferredFileExtension != "acm")
    }

    @Test("ACM URL is not treated as filename")
    func acmURLIsNotFilename() {
        let intent = router.detect(
            prompt: "Use ACM format from https://www.acm.org/publications/authors/reference-formatting",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.requestedFilename == nil)
        #expect(intent.inferredFileExtension != "acm")
    }

    @Test("File integrity question stays answer")
    func fileIntegrityQuestionIsAnswer() {
        let intent = router.detect(
            prompt: "what is file integrity?",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .answer)
    }

    @Test("Explicit Desktop HTML is artifact")
    func desktopHTMLIsArtifact() {
        let intent = router.detect(
            prompt: "make desktop_atoms.html and put it on my Desktop",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .createArtifact)
        #expect(intent.inferredFileExtension == "html")
        #expect(intent.requestedFilename == "desktop_atoms.html")
    }

    @Test("Normal writing prompt without save instruction stays answer")
    func normalWritingPromptStaysAnswer() {
        let intent = router.detect(
            prompt: "write me two paragraphs about Bloom filters for cybersecurity",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .answer)
        #expect(intent.requestedFilename == nil)
    }

    @Test("Document questions route to file summary tools")
    func documentQuestionsRouteToRAGTools() {
        let intent = router.detect(
            prompt: "What does my syllabus say about late work?",
            includeClipboard: false,
            workspaceRoot: workspaceRoot,
            hasClipboardText: false
        )

        #expect(intent.kind == .fileSummary)
        #expect(router.requiresGhostTools(prompt: "What does my syllabus say about late work?", intent: intent))
    }
}

@Suite("Deterministic calendar event parser")
struct DeterministicCalendarEventParserTests {
    private let parser = DeterministicCalendarEventParser()

    @Test("Parses simple calendar event creation")
    func parsesSimpleEventCreation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-06-26T12:00:00Z")!

        let parsed = try #require(parser.parse(
            "create a calendar event tomorrow at 8pm called Study",
            now: now,
            calendar: calendar
        ))

        #expect(parsed.title == "Study")
        let dateComponents = calendar.dateComponents([.hour, .minute], from: parsed.startDate)
        #expect(dateComponents.hour == 20)
        #expect(dateComponents.minute == 0)
    }

    @Test("Does not parse calendar reads as creation")
    func doesNotParseCalendarReads() {
        let parsed = parser.parse("what is on my calendar tomorrow?")
        #expect(parsed == nil)
    }
}
