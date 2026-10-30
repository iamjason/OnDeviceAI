import Foundation
import Testing
@testable import OnDeviceAI

struct ScriptedModel: TextModel {
    var availability: ModelAvailability = .available
    var reply: @Sendable (String, String?) throws -> String

    func respond(to prompt: String, instructions: String?, options: ResponseOptions) async throws -> String {
        try reply(prompt, instructions)
    }
}

struct Failure: Error {}

@Suite struct HeuristicsTests {
    @Test func titleDropsQuestionFillerAndCuts() {
        let title = Heuristics.title(from: "Which action keys are the 'W12' log-only keys in the 2.3 table?", maxWords: 4)
        #expect(title == "Action keys are the…")
    }

    @Test func titleKeepsAShortSentenceWhole() {
        #expect(Heuristics.title(from: "Badge tone mapping. Is Alert right?", maxWords: 5) == "Badge tone mapping")
    }

    @Test func titleOfNothingIsUntitled() {
        #expect(Heuristics.title(from: "   ") == "Untitled")
    }

    @Test func cleanTitleStripsQuotesLabelsAndPunctuation() {
        #expect(Heuristics.cleanTitle("Title: \"W12 log-only keys.\"\nExtra line", maxWords: 5) == "W12 log-only keys")
        #expect(Heuristics.cleanTitle("**Heap dump in commit**", maxWords: 3) == "Heap dump in")
        #expect(Heuristics.cleanTitle("  \n ", maxWords: 3) == nil)
    }

    @Test func summaryIsTheFirstSentences() {
        #expect(Heuristics.summary(of: "One thing.  Two\nthings. Three.", maxSentences: 2) == "One thing. Two things.")
    }
}

@Suite struct TextTasksTests {
    @Test func titleComesFromTheModelCleanedUp() async {
        let tasks = TextTasks(model: ScriptedModel { _, instructions in
            #expect(instructions?.contains("terminal tab") == true)
            return "\"Badge tone mapping.\""
        })
        #expect(await tasks.title(for: "Badge tone mapping: is Alert right?", context: "a terminal tab") == "Badge tone mapping")
    }

    @Test func titleFallsBackWhenTheModelFails() async {
        let tasks = TextTasks(model: ScriptedModel { _, _ in throw Failure() })
        #expect(await tasks.title(for: "Should we delete the heap dump?", maxWords: 3) == "We delete the…")
    }

    @Test func titleFallsBackToTheCallersFallback() async {
        let failing = TextTasks(model: ScriptedModel { _, _ in throw Failure() })
        #expect(await failing.title(for: "Build command: xcodebuild test", fallback: "Build 7") == "Build 7")
        let missing = TextTasks(model: UnavailableModel(reason: "test"))
        #expect(await missing.title(for: "Build command: xcodebuild test", fallback: "Build 7") == "Build 7")
    }

    @Test func titleFallsBackWithoutAModel() async {
        let tasks = TextTasks(model: UnavailableModel(reason: "test"))
        #expect(await tasks.title(for: "Badge tone mapping") == "Badge tone mapping")
    }

    @Test func summaryFallsBackToTheFirstSentence() async {
        let tasks = TextTasks(model: UnavailableModel(reason: "test"))
        #expect(await tasks.summary(of: "First. Second.") == "First.")
    }

    @Test func unavailableModelThrows() async {
        await #expect(throws: TextModelError.unavailable(reason: "nope")) {
            try await UnavailableModel(reason: "nope").respond(to: "hi")
        }
    }
}

/// Asks the real on-device model. Opt in with ONDEVICEAI_LIVE=1 on a Mac with Apple Intelligence on.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ONDEVICEAI_LIVE"] == "1"))
struct LiveModelTests {
    @Test func titlesAQuestion() async {
        let model = systemTextModel()
        print("availability:", model.availability)
        let tasks = TextTasks(model: model)
        for text in [
            "Which action keys are the 'W12' log-only keys in the 2.3 table?",
            "Badge tone mapping: is Alert for coverage + payment-alert statuses, Success for completed/is_completed, Neutral otherwise right?",
            "A 9.7 GB lint heap dump (java_pid29413.hprof) got committed in 699e64c381 (unpushed). Rewriting it out needs reset/restore, which my tools can't run.",
        ] {
            print("title:", await tasks.title(for: text, maxWords: 4, context: "a terminal tab where a developer discusses this question from a coding agent"))
        }
    }
}
