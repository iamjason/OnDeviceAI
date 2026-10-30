# OnDeviceAI

Small, reusable wrappers around Apple's on-device language model (the Foundation Models framework) for the
everyday jobs apps want from it: a short title, a one-line summary, a quick free-form answer.

- **Never blocks on availability.** `TextTasks` falls back to model-free heuristics when the OS predates
  Foundation Models (macOS/iOS 26), the device isn't eligible, Apple Intelligence is off, or the model errors or
  refuses. Callers can show its result unconditionally.
- **Backend-agnostic.** Everything goes through the `TextModel` protocol; `AppleOnDeviceModel` is one conformer,
  `UnavailableModel` another, and tests (or a server model) can supply their own.
- Deploys to macOS 14 / iOS 17 / visionOS 1; the Apple model is used only where `#available`.

## Use

```swift
.package(url: "https://github.com/iamjason/OnDeviceAI.git", from: "0.1.0")
```

```swift
import OnDeviceAI

let tasks = TextTasks()   // systemTextModel(): Apple's on-device model when it's there
let title = await tasks.title(
    for: "Which action keys are the 'W12' log-only keys in the 2.3 table?",
    maxWords: 4,
    context: "a terminal tab where a developer discusses this question")
// "Log-only keys W12" (or "Action keys are the…" from the heuristic fallback)

let summary = await tasks.summary(of: longText, maxSentences: 2)

// Free-form, throwing:
let model = systemTextModel()
if model.availability.isAvailable {
    let answer = try await model.respond(to: "…", instructions: "Answer in one word.")
}
```

## Test

```sh
swift test                         # heuristics and fallbacks, no model needed
ONDEVICEAI_LIVE=1 swift test       # also asks the real on-device model
```
