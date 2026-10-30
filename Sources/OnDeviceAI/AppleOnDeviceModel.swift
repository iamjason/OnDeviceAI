#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Apple's on-device language model (the Foundation Models framework). Each response gets its own session, so
/// calls don't share a transcript and can run concurrently.
@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
public struct AppleOnDeviceModel: TextModel {
    /// The input is cut to this many characters: the model's context window is small (4K tokens), and a title or
    /// summary doesn't need more.
    public var maximumPromptCharacters: Int

    public init(maximumPromptCharacters: Int = 6_000) {
        self.maximumPromptCharacters = maximumPromptCharacters
    }

    public var availability: ModelAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: Self.describe(reason))
        @unknown default:
            return .unavailable(reason: "The on-device model is unavailable.")
        }
    }

    public func respond(to prompt: String, instructions: String?, options: ResponseOptions) async throws -> String {
        if case .unavailable(let reason) = availability { throw TextModelError.unavailable(reason: reason) }
        let session = LanguageModelSession(instructions: instructions)
        let generation = GenerationOptions(
            temperature: options.temperature, maximumResponseTokens: options.maximumResponseTokens)
        let response = try await session.respond(to: String(prompt.prefix(maximumPromptCharacters)), options: generation)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw TextModelError.emptyResponse }
        return text
    }

    static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible: "This device can't run Apple Intelligence."
        case .appleIntelligenceNotEnabled: "Apple Intelligence is turned off in System Settings."
        case .modelNotReady: "The on-device model is still downloading."
        @unknown default: "The on-device model is unavailable."
        }
    }
}
#endif
