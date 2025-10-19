# Foundation Model Emoji Selection — Product Requirements Document (PRD)

## Overview
Upgrade Cubby’s item creation flow so that the default emoji selected for a new inventory item is chosen by Apple’s on-device foundation language model instead of by random fallback. When the model is unavailable, the current random emoji picker remains in place.

## Problem Statement
Random emoji assignments sometimes feel irrelevant or jarring, reducing the sense that the app understands the user’s items. We want a lightweight, private way to select contextually appropriate emojis without adding friction to item creation.

## Goals
- Deliver a more semantically relevant emoji for each new item title.
- Keep the item creation save flow feeling instant; AI work must not block persistence.
- Rely solely on on-device Apple Foundation Models (no server or third-party calls) to preserve privacy and eliminate per-call costs.

## Non-Goals
- No new UI in v1 (no confirmation modals, pickers, or undo workflow specifically for the emoji).
- No automatic re-run of the emoji suggestion when an item title changes after creation.
- No metrics or analytics dashboards for tracking AI usage in v1.

## User Story
As a homeowner adding a new item, I want Cubby to automatically assign an emoji that fits the item’s title so that my inventory feels organized and meaningful without any extra effort.

## Experience Flow
1. User fills out the new item form and taps Save.
2. Item is saved immediately with the existing random emoji logic (status quo behavior).
3. In the background, the app checks for Foundation Model availability and, if available, requests a single emoji recommendation using the item title.
4. If a model response arrives (expected ≈150–400 ms on modern devices), the item’s emoji is updated in place.
5. If the model is unavailable, errors, or times out, the original random emoji remains.
6. The user does not see intermediate UI states; the emoji simply updates quietly if a better one arrives.

## Functional Requirements
- **Trigger:** Run the AI emoji selection immediately after a successful item save event (using the item title only).
- **Prompt Content:** Provide the model the item title and a short instruction to return a single Unicode emoji character most closely associated with the title’s meaning.
- **Single Result:** Persist only the top suggestion; no ranked list or Genmoji generation in v1.
- **Async Update:** Perform AI inference on a background task. Persist the result to the existing item record when it arrives without blocking the user.
- **Fallback:** When the Foundation Models framework is unavailable (unsupported OS, Apple Intelligence disabled, or necessary assets missing) or a request fails, skip AI inference and keep the random emoji.
- **Idempotency:** If multiple inference attempts fire for the same item (e.g., due to retries), only the first successful suggestion should win; subsequent results are ignored.
- **Edits After Creation:** Changing an item title after creation does not automatically trigger a new AI selection; users keep the current emoji unless they manually change it via existing controls.
- **Logging:** Emit `DebugLogger` entries for every major step—model availability detection, inference request start, successful completion (with latency and returned emoji), and fallback/timeout cases.

## Technical Notes
- Detect model availability via the Foundation Models framework before enqueuing work; avoid prompting users to download assets and log the availability check result (device class, OS, and model identifier when exposed).
- Target the on-device 3B language model via `LanguageModelSession` with a concise prompt template.
- Apply a short timeout (e.g., 750 ms) so slow requests don’t hold background resources.
- Sanitize the response to ensure it is exactly one emoji; fall back if parsing fails.
- Persist updates through the existing SwiftData model context to ensure views refresh via @Query.
- Capture and log any metrics surfaced by the foundation model response (e.g., token counts, finish reason, safety flags) to aid diagnostics while keeping payloads free of user content.

## Logging & Observability
- **Availability Detection:** Log when the app confirms the on-device foundation model is usable or not (include reason when unavailable).
- **Inference Lifecycle:** Log start and end events with timestamps so elapsed time can be computed; include timeout vs. success vs. failure outcomes.
- **Result Summary:** Log the suggested emoji character and finish reason, avoiding the original item title to prevent PII in logs.
- **Error Handling:** Log descriptive error messages for framework failures (session creation, generation errors, parsing failures) with error codes.
- **Throttling:** Ensure logs are rate-limited if multiple retries occur to avoid log spam.

## Edge Cases & Constraints
- Empty titles should bypass AI inference and preserve the random emoji (log that the request was skipped).
- Offline mode is fully supported because the model is on-device; no network dependency.
- Ensure background updates respect the maximum nesting depth and relationships in SwiftData (avoid context detachment by using IDs when fetching for update).

## Success Metrics
- Higher perceived relevance of auto-assigned emojis in qualitative feedback (user interviews, App Store reviews, or support tickets).
- No increase in item save latency (end-to-end save remains baseline fast).
- Error rate for on-device inference remains under 5%; otherwise reassess fallback frequency.

## Open Questions / Future Considerations
- Should we expose a manual “Regenerate emoji” control when editing items?
- Could we store lightweight metadata (e.g., `emojiSource = ai/random`) to support future analytics?
- When Apple releases Genmoji APIs, should we allow optional custom emoji generation for premium users?
