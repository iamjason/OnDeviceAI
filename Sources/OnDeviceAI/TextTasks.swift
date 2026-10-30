import Foundation

/// Small everyday jobs for a language model (a title, a one-line summary) that never fail: when the model is
/// missing, refuses, or errors, the answer comes from `Heuristics` instead, so callers can show it unconditionally.
public struct TextTasks: Sendable {
    public let model: any TextModel

    public init(model: any TextModel = systemTextModel()) {
        self.model = model
    }

    /// A short title for TEXT, at most MAX_WORDS words, like a tab or window title. CONTEXT says what the title
    /// is for ("a terminal tab where a developer discusses this question"), which helps the model pick what matters.
    public func title(for text: String, maxWords: Int = 5, context: String? = nil) async -> String {
        let fallback = Heuristics.title(from: text, maxWords: maxWords)
        guard model.availability.isAvailable else { return fallback }
        var instructions = [
            "You write very short titles. Reply with only the title: at most \(maxWords) words, no quotes, no "
                + "trailing punctuation, no prefix like \"Title:\". Name the specific subject (the thing, not the "
                + "question form): keep identifiers, product names and numbers that tell it apart, and prefer the words the text itself uses.",
        ]
        if let context { instructions.append("The title is for \(context).") }
        do {
            let raw = try await model.respond(
                to: text, instructions: instructions.joined(separator: " "),
                options: ResponseOptions(temperature: 0.2, maximumResponseTokens: 32))
            return Heuristics.cleanTitle(raw, maxWords: maxWords) ?? fallback
        } catch {
            return fallback
        }
    }

    /// TEXT in at most MAX_SENTENCES sentences.
    public func summary(of text: String, maxSentences: Int = 1, context: String? = nil) async -> String {
        let fallback = Heuristics.summary(of: text, maxSentences: maxSentences)
        guard model.availability.isAvailable else { return fallback }
        var instructions = [
            "Summarize the user's text in at most \(maxSentences) plain sentence\(maxSentences == 1 ? "" : "s"). "
                + "Reply with only the summary.",
        ]
        if let context { instructions.append("The summary is for \(context).") }
        do {
            let raw = try await model.respond(
                to: text, instructions: instructions.joined(separator: " "),
                options: ResponseOptions(temperature: 0.2, maximumResponseTokens: 40 * maxSentences + 20))
            let cleaned = Heuristics.collapseWhitespace(raw)
            return cleaned.isEmpty ? fallback : cleaned
        } catch {
            return fallback
        }
    }
}
