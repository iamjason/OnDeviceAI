import Foundation

/// A model that turns a prompt into text. `AppleOnDeviceModel` is Apple's on-device model (Foundation Models);
/// tests and other backends conform too, so callers never depend on one directly.
public protocol TextModel: Sendable {
    /// Whether `respond` can work right now, and why not when it can't.
    var availability: ModelAvailability { get }

    /// The model's answer to PROMPT, steered by INSTRUCTIONS (the system prompt).
    func respond(to prompt: String, instructions: String?, options: ResponseOptions) async throws -> String
}

public enum ModelAvailability: Sendable, Equatable {
    case available
    /// REASON says why, for logs and settings screens ("Apple Intelligence is turned off").
    case unavailable(reason: String)

    public var isAvailable: Bool { self == .available }
}

/// How a response is sampled. Backends ignore what they don't support.
public struct ResponseOptions: Sendable, Equatable {
    /// 0 is as repeatable as the model allows; higher is more varied. Nil is the model's default.
    public var temperature: Double?
    /// A cap on the response's length, in tokens. Nil is the model's default.
    public var maximumResponseTokens: Int?

    public init(temperature: Double? = nil, maximumResponseTokens: Int? = nil) {
        self.temperature = temperature
        self.maximumResponseTokens = maximumResponseTokens
    }
}

public enum TextModelError: Error, Sendable, Equatable, LocalizedError {
    case unavailable(reason: String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): "The language model isn't available: \(reason)"
        case .emptyResponse: "The language model returned nothing."
        }
    }
}

/// A model that never answers: the stand-in where Apple's isn't there (an older OS, an ineligible device).
public struct UnavailableModel: TextModel {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public var availability: ModelAvailability { .unavailable(reason: reason) }

    public func respond(to prompt: String, instructions: String?, options: ResponseOptions) async throws -> String {
        throw TextModelError.unavailable(reason: reason)
    }
}

extension TextModel {
    public func respond(to prompt: String, instructions: String? = nil) async throws -> String {
        try await respond(to: prompt, instructions: instructions, options: ResponseOptions())
    }
}

/// The best model this device has: Apple's on-device model where the OS has it, else `UnavailableModel`.
/// Check `availability` before relying on it; `TextTasks` falls back to heuristics on its own.
public func systemTextModel() -> any TextModel {
    #if canImport(FoundationModels)
    if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) {
        return AppleOnDeviceModel()
    }
    #endif
    return UnavailableModel(reason: "This OS predates Apple's on-device model (macOS 26, iOS 26).")
}
