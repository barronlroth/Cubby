# Cubby Design System

Cubby's design foundations live in `Cubby/DesignSystem` under the `CubbyDesign` namespace. The system is intentionally small: it gives new and touched UI one semantic source of truth without requiring a broad migration of stable feature screens.

## Foundations

### Typography

Use `CubbyDesign.Typography` roles instead of constructing custom fonts in views. The roles cover brand display text, navigation and content hierarchy, supporting labels, and fine print. Custom font names are private implementation details, and every custom role declares a `relativeTo` text style so it participates in Dynamic Type.

System text styles remain preferred for native controls and familiar platform hierarchy when a branded role adds no value. Do not add `Font.custom` outside `CubbyTypography.swift`.

### Color

Use `CubbyDesign.Palette` for shared semantic colors. `canvas`, `homeCanvas`, and `itemIconBackground` are backed by adaptive asset-catalog colors. System-derived tokens such as `surface`, `primaryText`, `separator`, and `destructive` preserve platform contrast behavior.

Do not access shared color assets by string name from feature code. Add light and dark appearances when introducing an asset-backed semantic color, then expose it through `Palette`.

### Spacing and layout

Use `CubbyDesign.Spacing` for relationships between elements and `CubbyDesign.Layout` for reusable dimensions such as minimum tap targets, common icon sizes, and readable content width. These are defaults, not a mandate to replace geometry that is intrinsically tied to an image, system control, or available container size.

### Shape, stroke, elevation, and surfaces

Use `CubbyDesign.Radius` and `CubbyDesign.Stroke` for shared shapes. `CubbyDesign.Elevation` defines the supported shadow levels. Apply `cubbySurface(_:)` with `.flat`, `.card`, or `.raised` when a custom container needs the standard combination of adaptive fill, continuous corner radius, hairline stroke, and elevation.

Prefer native `Form`, `List`, button, sheet, and material treatments when they already provide the intended platform surface.

### Motion

Use `cubbyAnimation(_:value:)` for implicit animations. It reads `cubbyReduceMotion`, which resolves the production accessibility setting plus the design-validation override. For explicit state changes and continuous motion, read `@Environment(\.cubbyReduceMotion)` and pass the value through `CubbyDesign.Motion` inside `withAnimation` or before starting repeated work.

Choose the token by intent:

- `quick`: compact disclosure and visibility changes.
- `standard`: ordinary state transitions.
- `emphasized`: a single important arrival or confirmation.

Continuous, decorative, parallax, scale, and repeated motion must provide an immediate or non-moving Reduce Motion path even when a token is not a good fit.

## Component and state expectations

Every new reusable component should define and preview the states that apply:

- Default, pressed, selected, focused, and disabled.
- Loading, empty, error, and unavailable when content is asynchronous or gated.
- Light and dark appearance.
- Large accessibility text sizes without clipped primary content.
- Reduce Motion behavior for any transition or animated feedback.
- VoiceOver labels, values, hints, and grouping where the visible content is not sufficient.

Interactive controls should use native `Button`, `Toggle`, and other controls where possible and meet the 44-point minimum tap target. Color must not be the only indication of state.

## Adoption rules

1. New UI uses the semantic APIs in `CubbyDesign`.
2. Touched UI adopts the relevant tokens when doing so preserves behavior and scope.
3. Existing stable feature screens do not need mechanical wholesale migration.
4. Prefer semantic role names over aliases tied to one screen or raw visual values.
5. Add a foundation token only when a value is shared or establishes a deliberate reusable rule.
6. Keep shared asset names, custom font names, and reusable shadow recipes inside the design-system layer. Feature-specific continuous motion may branch locally, but it must honor Reduce Motion.
7. Add focused tests for token ordering, constraints, or policy resolution when the logic is testable without snapshot assertions.

## Allowed exceptions

- The Pro paywall retains its local `PaywallPalette` and bespoke surface composition. It is a deliberate campaign-style experience and is not the reference for general app UI. Its text still uses shared typography roles for Dynamic Type.
- Illustration and photography colors may stay local when they are content rather than interface semantics.
- Media aspect ratios and image-dependent dimensions may use local geometry.
- UIKit interop may use UIKit semantic colors at the boundary; SwiftUI feature code should consume `CubbyDesign.Palette`.
- A one-off value may remain local when turning it into a token would imply reuse that does not exist. Document the reason if the exception is not obvious.

## Design validation

Run the shared `Cubby Design Validation` scheme with `CubbyDesignValidation.xctestplan`. Baseline and Accessibility Text are expected on the standard iPhone 17 Pro destination. Run Compact Device on iPhone 17e (or another simulator whose portrait window is 390 points wide or narrower); the tests intentionally fail when that configuration is sent to a wider destination. Reduce Motion injects the validation override into `cubbyReduceMotion`, so token animations and continuous-motion guards take the same branches used for the system accessibility setting.
