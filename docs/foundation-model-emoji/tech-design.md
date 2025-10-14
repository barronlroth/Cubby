# Foundation Model Emoji Selection — Technical Design

## Overview
This document translates the PRD into an actionable implementation plan for replacing Cubby’s random emoji assignment with an on-device Apple Foundation Model suggestion, complete with comprehensive logging for observability and debugging.

## Scope
- Applies only to the item creation flow (new inventory items).
- Touches SwiftData update path for `InventoryItem` emoji mutation.
- Adds a new service layer responsible for foundation model interactions and logging.
- Adds no new UI in v1.

## High-Level Architecture
```
AddItemView / ItemCreationViewModel
            │
            ├── persist new InventoryItem (existing flow)
            │
            └── EmojiAssignmentCoordinator
                    │
                    ├─▶ RandomEmojiProvider (existing)
                    └─▶ FoundationModelEmojiService (new)
                                │
                                ├─ check availability & log
                                ├─ request suggestion (async)
                                ├─ log metrics / outcome
                                └─ persist emoji update via SwiftData context
```

### Key Control Flow
1. Item save completes; the user sees no delay.
2. `EmojiAssignmentCoordinator` schedules a background task via Swift concurrency (Task) using the saved item’s persistent identifier.
3. Coordinator invokes `FoundationModelEmojiService` which:
   - Logs device capabilities and availability on first use per launch.
   - Instantiates a `LanguageModelSession` targeting the 3B on-device model.
   - Issues a prompt using the item title and awaits a single-token emoji response (with timeout).
   - Logs request start/end with latency, finish reason, token usage, safety signals, or errors.
   - Validates the emoji character and updates the item through a fresh fetch using the ID.
4. Fallbacks (availability failure, timeout, parsing failure) are logged and leave the random emoji untouched.

## Components

### EmojiAssignmentCoordinator (new helper, or augmentation of existing coordinator)
- Responsibility: orchestrate post-save emoji operations.
- Exposed API: `func postSaveEmojiEnhancement(for itemID: PersistentIdentifier)`.
- Dependencies: `RandomEmojiProvider`, `FoundationModelEmojiService`, `ModelContextProvider`.
- Behavior:
  - Immediately returns after launching an async Task.
  - Uses `guard` to skip if title is empty; logs skip via `DebugLogger.info`.
  - Ensures only one concurrent AI attempt per item (track `inflightItemIDs` Set or rely on task isolation).

### FoundationModelEmojiService
- Encapsulates Apple Foundation Models framework usage.
- Key methods:
  - `func suggestEmoji(for title: String) async throws -> SuggestionResult` where `SuggestionResult` contains `emoji`, `latency`, `usageMetrics`, `finishReason`, `safetySignal`.
  - `func isModelAvailable() -> Availability` caching the outcome (device, OS, Apple Intelligence state).
- Availability check implementation:
  - Use `FoundationModelsAvailability.check()` (placeholder — actual API TBD) or `LanguageModelSession.descriptor(for:)` try/catch.
  - Log `deviceModel`, `systemVersion`, and availability result once per app launch (guard with `didLogAvailability`).
- Prompt template:
  ```swift
  "You are an assistant that returns a single emoji matching the meaning of '\(title)'. Reply with exactly one emoji character."
  ```
- Timeout via `withTaskCancellationHandler` + `Task.sleep` or `Task` cancellation after 750 ms.
- Parse response ensuring:
  - Non-empty string
  - Contains exactly one extended grapheme cluster that is an emoji (`Character.isEmoji`).
  - Log parsing failures and throw `SuggestionError.invalidResponse`.

### ModelContextProvider (existing pattern)
- Supplies a short-lived SwiftData `ModelContext` (likely `@MainActor` via environment or background context) to re-fetch the item by ID and apply the emoji update.
- Ensure context operations are on the appropriate actor; log success/failure of persistence.

## Logging Strategy
All logging uses `DebugLogger` with consistent prefixes (`[EmojiAI]`). Log levels chosen by severity (info, warn, error).

| Event | Log Level | Sample Message Payload |
|-------|-----------|------------------------|
| Availability detected | info | `[EmojiAI] Foundation model available=true model=LM-3B device=iPhone16,2 os=26.0` |
| Availability failure | warn | `[EmojiAI] Foundation model unavailable reason=appleIntelligenceDisabled` |
| Title skipped | info | `[EmojiAI] Skipping AI suggestion for empty title itemID=...` |
| Request start | info | `[EmojiAI] Suggestion start itemID=... promptTokens=~ titleHash=...` (hash to avoid raw title) |
| Request completion | info | `[EmojiAI] Suggestion success itemID=... emoji=📦 latencyMs=182 outputTokens=1 finish=completed safety=none` |
| Timeout | warn | `[EmojiAI] Suggestion timeout itemID=... elapsedMs=750` |
| Framework error | error | `[EmojiAI] Suggestion failed itemID=... errorCode=... description=...` |
| Persistence update | info | `[EmojiAI] Updated item emoji itemID=... source=foundationModel` |

Additional metrics captured when APIs expose them:
- `usage.promptTokenCount`, `usage.outputTokenCount`.
- `responseDiagnostics.safetyLevel` or equivalent flags.
- `finishReason` from the generation result.

Rate limiting: wrap repeated error logs with an exponential backoff or limit logs per item within a short window to avoid spam.

## Error Handling & Fallbacks
- **Availability false** → log and exit early.
- **Session creation throws** → log error, exit.
- **Inference throws** → differentiate between timeout, cancellation, and model errors; log; exit.
- **Parsing failure** → log warning, exit.
- **Persistence failure** → log error, optionally retry once (`Task.detached` with delay) but avoid infinite loops.

## SwiftData Update Pattern
```swift
func applyEmoji(_ emoji: String, to itemID: PersistentIdentifier) async {
    await mainActorContext.perform {
        guard let item = context.item(for: itemID) else {
            DebugLogger.warn("[EmojiAI] Item not found for emoji update itemID=\(itemID)")
            return
        }
        item.emoji = emoji
        try? context.save()
        DebugLogger.info("[EmojiAI] Updated item emoji itemID=\(itemID) source=foundationModel")
    }
}
```
- Use ID-based lookup to avoid reference detachment.
- Save only if the emoji has changed.

## Concurrency Considerations
- Use `Task(priority: .background)` from coordinator.
- Cancellation: if app moves to background or item deleted before completion, cancel the task; log cancellation at debug level.
- For multiple simultaneous saves, the service handles each independently; caching availability avoids repeated expensive checks.

## Testing Strategy
- **Unit Tests**
  - Mock `FoundationModelEmojiService` returning deterministic emojis and ensure coordinator updates items as expected.
  - Simulate availability false to verify random emoji remains and logs emitted.
  - Test logging hooks by injecting a `DebugLogger` spy (if existing infrastructure allows).
- **Integration Tests**
  - On simulator/devices running iOS 26 with Apple Intelligence enabled, create items and verify emoji updates within expected latency.
  - Test timeout path by stubbing delayed responses.
- **Regression**
  - Ensure existing random emoji logic still executes for unsupported OS (pre-iOS 26) by unit tests that bypass the new service.

## Tooling & Build Impacts
- Requires adding the Foundation Models framework to target link settings (if not already included).
- Introduce feature flag (compile-time or runtime) if we need to gate shipping (optional but recommended).

## Risks & Mitigations
- **Model asset missing**: ensure availability check gracefully handles download prompts and logs reason.
- **High latency**: short timeout prevents user-visible lag; consider adding metrics to revisit threshold.
- **Logging PII**: hash titles or omit raw content in logs to keep privacy intact.
- **API evolution**: Foundation Models framework is new; wrap calls to make future upgrades easier (single service abstraction).

## Open Items
- Confirm exact API names once Apple publishes final Foundation Models SDK for iOS 26; adjust service accordingly.
- Decide whether to introduce an `emojiSource` field for future analytics (currently out-of-scope, but logging includes `source` tags).
