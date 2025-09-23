# Auto Emoji Assignment PRD

## Purpose
Enable every new item to receive an on-device AI-selected emoji driven by Apple Foundation Models to boost scannability and delight.

## Problem & Goals
- Filing items today yields a plain text list that feels flat and harder to scan.
- Manual emoji picking is inconsistent and slows creation.
- Goal is playful structure that aids recall, keeps flow fast, and respects privacy via on-device inference.

## Target Users & Scenarios
- Power organizers batching ideas want quick visual anchors per entry.
- Teams cataloguing shared tasks benefit when the emoji hints at task theme.
- Heavy mobile users entering items on the go expect offline performance.
- Accessibility users relying on screen readers need emoji accompanied by descriptive labels.

## User Stories
1. As a creator, when I finish typing a title or description, I instantly see a suggested emoji.
2. As a user, I can tap the emoji chip to cycle alternatives or clear it.
3. As an editor, I can lock my override so AI will not overwrite later edits.
4. As a team admin, I can see emoji suggestions respect workspace content policies.

## Key Experience Notes
- Emoji appears with a subtle fade-in beside the item title field on submit.
- Quick actions: tap to open a three-option carousel (AI pick plus two alternates).
- Long-press exposes “Remove emoji” and “AI resuggest”.
- Tooltip or inline text clarifies “Emoji suggested on-device with Apple Foundation Model”.

## Functional Requirements
- Trigger inference on the title every time the user stops typing for 600 ms or on submit.
- Optionally include description text, capped at 200 characters, as part of the prompt.
- Return candidate emoji and confidence; accept suggestions when confidence ≥0.55 (default, tunable).
- Provide fallback to category-based heuristic if AI fails or confidence is below threshold.
- Store the final emoji with item metadata and sync to web and mobile clients.
- Surface override controls in item detail and edit flows.
- Log aggregated telemetry (confidence bucket, accepted/overridden) without storing raw text.

## Non-Functional Requirements
- On-device inference (macOS and iOS) using Apple Foundation Models; avoid network calls.
- End-to-end latency target ≤100 ms (P90) on M-series Macs, ≤150 ms on A17 devices.
- Memory budget ≤300 MB when the model is loaded; lazily load after first focus on the field.
- Respect accessibility requirements: aria-label announces selected emoji name.
- Localization: ensure emoji labels map to locale-specific strings.
- Privacy: no content leaves the device; comply with internal data minimization policies.

## Technical Approach
- Integrate Apple Foundation Models (FoundationModels framework) with `FMLanguageModel` for lightweight text-to-icon classification.
- Create prompt template with instructions plus enumerated emoji shortlist to guardrail outputs.
- Fine-tune preference via curated prompt engineering and optional LoRA adaptation if Apple enables custom adapters.
- Derive confidence scores from model log probabilities; map to emoji taxonomy built from Unicode categories and product-specific list.
- Cache top three results per normalized title hash to avoid recomputation.
- Mobile: leverage Core ML packaging; ensure fallback heuristics when the model is unavailable.
- Telemetry: emit counts only; store locally and sync aggregated events on schedule.
- Testing: use synthetic dataset (≈1,000 labeled title→emoji pairs) for regression; run on-device unit tests; add golden snapshot tests for deterministic prompts.

## Dependencies & Partners
- Coordinate with iOS and macOS client teams for UI updates.
- Legal and privacy sign-off on on-device inference messaging.
- Design support for emoji chips, interaction states, and accessibility copy.
- Data Science to supply evaluation corpus; QA to validate emoji coverage.

## Rollout Plan
1. Sprint 1: Prototype inference service and prompt tuning.
2. Sprint 2: Integrate with creation flow, add overrides, build telemetry.
3. Beta: Dogfood with internal list of 200 users; monitor acceptance rate and latency.
4. GA: Staged rollout (10%→50%→100%) gated on telemetry targets.

## Risks & Mitigations
- Model selects inappropriate emoji → maintain curated allowlist and apply safety filter.
- Latency spikes on lower-end devices → degrade gracefully to heuristic or delay emoji until after submit.
- Unclear user mental model → provide tooltips, settings toggle, and clear override semantics.
- Foundation Model API changes → pin SDK version and monitor release notes.

## Open Questions
- Should users customize preferred emoji categories per workspace?
- Do we need server-side precomputation for web clients without Apple silicon?
- Will Apple licensing permit bundling model weights in enterprise builds?

## Next Steps
1. Align with design on chip states and override interactions.
2. Confirm legal and privacy requirements for on-device AI messaging.
3. Build evaluation dataset for prompt tuning and regression tests.
