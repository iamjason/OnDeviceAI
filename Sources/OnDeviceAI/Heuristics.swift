import Foundation

/// Model-free fallbacks for `TextTasks`, and the cleanup applied to what a model returns.
public enum Heuristics {
    /// Leading words that make a title read as a question rather than name its subject.
    static let fillers: Set<String> = [
        "a", "an", "the", "is", "are", "was", "were", "do", "does", "did", "should", "can", "could", "would", "will",
        "which", "what", "how", "why", "when", "where", "who", "whether", "please", "so", "ok", "okay", "hey", "hi",
    ]

    /// The first sentence of TEXT, shortened to MAX_WORDS words with leading filler ("Which", "Is the") dropped,
    /// and an ellipsis when it was cut.
    public static func title(from text: String, maxWords: Int = 5) -> String {
        let sentence = firstSentence(of: text)
        var words = sentence.split(whereSeparator: \.isWhitespace).map(String.init)
        while words.count > 1, let first = words.first, fillers.contains(first.lowercased()) {
            words.removeFirst()
        }
        guard !words.isEmpty else { return "Untitled" }
        let cut = words.count > maxWords
        var title = words.prefix(max(1, maxWords)).joined(separator: " ")
        title = trimPunctuation(title)
        title = title.prefix(1).uppercased() + title.dropFirst()
        return cut ? title + "…" : title
    }

    /// The first MAX_SENTENCES sentences of TEXT, on one line.
    public static func summary(of text: String, maxSentences: Int = 1) -> String {
        let flat = collapseWhitespace(text)
        var sentences: [String] = []
        flat.enumerateSubstrings(in: flat.startIndex..., options: .bySentences) { sentence, _, _, stop in
            if let sentence { sentences.append(sentence.trimmingCharacters(in: .whitespaces)) }
            if sentences.count >= maxSentences { stop = true }
        }
        return sentences.isEmpty ? flat : sentences.joined(separator: " ")
    }

    /// A model's title made presentable: one line, without quotes, a "Title:" label, markdown or trailing
    /// punctuation, at most MAX_WORDS words. Nil when nothing is left.
    public static func cleanTitle(_ raw: String, maxWords: Int) -> String? {
        var line = raw.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        if let colon = line.firstIndex(of: ":"), line[..<colon].lowercased().trimmingCharacters(in: .whitespaces) == "title" {
            line = String(line[line.index(after: colon)...])
        }
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`*_#“”‘’ ").union(.whitespaces))
        line = trimPunctuation(line)
        let words = line.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return nil }
        return words.prefix(max(1, maxWords)).joined(separator: " ")
    }

    public static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func firstSentence(of text: String) -> String {
        let flat = collapseWhitespace(text)
        var first: String?
        flat.enumerateSubstrings(in: flat.startIndex..., options: .bySentences) { sentence, _, _, stop in
            first = sentence
            stop = true
        }
        return (first ?? flat).trimmingCharacters(in: .whitespaces)
    }

    static func trimPunctuation(_ text: String) -> String {
        var text = text
        while let last = text.last, ".,;:!?…-–—".contains(last) || last.isWhitespace { text.removeLast() }
        return text
    }
}
