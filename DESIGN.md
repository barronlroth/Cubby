---
version: alpha
name: Cubby
description: Warm, calm, native iPhone inventory design with branded editorial type and accessible interaction defaults.
colors:
  primary: "#007AFF"
  on-primary: "#FFFFFF"
  canvas-light: "#FAF9F6"
  canvas-dark: "#000000"
  home-canvas-light: "#F9F8F7"
  home-canvas-dark: "#1C1C1E"
  item-icon-light: "#ECDBBD"
  item-icon-dark: "#2E2922"
  surface-light: "#F2F2F7"
  surface-dark: "#1C1C1E"
  elevated-surface-light: "#FFFFFF"
  elevated-surface-dark: "#2C2C2E"
  on-surface-light: "#000000"
  on-surface-dark: "#FFFFFF"
  secondary-text-light: "#3C3C43"
  secondary-text-dark: "#EBEBF5"
  separator-light: "#3C3C43"
  separator-dark: "#545458"
  destructive: "#FF3B30"
typography:
  display-large:
    fontFamily: AwesomeSerif-ExtraTall
    fontSize: 50px
    fontWeight: 400
  display:
    fontFamily: AwesomeSerif-ExtraTall
    fontSize: 40px
    fontWeight: 400
  title:
    fontFamily: AwesomeSerif-ExtraTall
    fontSize: 36px
    fontWeight: 400
  navigation-title:
    fontFamily: AwesomeSerif-ExtraTall
    fontSize: 20px
    fontWeight: 400
  body-large:
    fontFamily: CircularStd-Book
    fontSize: 20px
    fontWeight: 400
  body:
    fontFamily: CircularStd-Book
    fontSize: 17px
    fontWeight: 400
  body-emphasized:
    fontFamily: CircularStd-Medium
    fontSize: 17px
    fontWeight: 500
  body-compact-emphasized:
    fontFamily: CircularStd-Medium
    fontSize: 16px
    fontWeight: 500
  body-small-emphasized:
    fontFamily: CircularStd-Medium
    fontSize: 15px
    fontWeight: 500
  body-small:
    fontFamily: CircularStd-Book
    fontSize: 14px
    fontWeight: 400
  section-title:
    fontFamily: CircularStd-Medium
    fontSize: 20px
    fontWeight: 500
  path:
    fontFamily: CircularStd-MediumItalic
    fontSize: 14px
    fontWeight: 500
  caption:
    fontFamily: CircularStd-Book
    fontSize: 13px
    fontWeight: 400
  caption-emphasized:
    fontFamily: CircularStd-Medium
    fontSize: 13px
    fontWeight: 500
  label:
    fontFamily: CircularStd-Medium
    fontSize: 12px
    fontWeight: 500
  caption-small:
    fontFamily: CircularStd-Book
    fontSize: 12px
    fontWeight: 400
  fine-print:
    fontFamily: CircularStd-Book
    fontSize: 11px
    fontWeight: 400
  fine-print-emphasized:
    fontFamily: CircularStd-Medium
    fontSize: 11px
    fontWeight: 500
  call-to-action:
    fontFamily: CircularStd-Medium
    fontSize: 17px
    fontWeight: 500
rounded:
  sm: 8px
  md: 12px
  lg: 18px
  xl: 24px
  full: 999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  base: 16px
  lg: 20px
  xl: 24px
  2xl: 32px
  3xl: 40px
components:
  app-canvas-light:
    backgroundColor: "{colors.canvas-light}"
    textColor: "{colors.on-surface-light}"
  app-canvas-dark:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.on-surface-dark}"
  home-canvas-light:
    backgroundColor: "{colors.home-canvas-light}"
    textColor: "{colors.secondary-text-light}"
  home-canvas-dark:
    backgroundColor: "{colors.home-canvas-dark}"
    textColor: "{colors.secondary-text-dark}"
  card-light:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.on-surface-light}"
    rounded: "{rounded.lg}"
    padding: "{spacing.base}"
  card-dark:
    backgroundColor: "{colors.surface-dark}"
    textColor: "{colors.on-surface-dark}"
    rounded: "{rounded.lg}"
    padding: "{spacing.base}"
  raised-light:
    backgroundColor: "{colors.elevated-surface-light}"
    textColor: "{colors.on-surface-light}"
    rounded: "{rounded.xl}"
  raised-dark:
    backgroundColor: "{colors.elevated-surface-dark}"
    textColor: "{colors.on-surface-dark}"
    rounded: "{rounded.xl}"
  item-icon-light:
    backgroundColor: "{colors.item-icon-light}"
    textColor: "{colors.on-surface-light}"
    rounded: "{rounded.md}"
  item-icon-dark:
    backgroundColor: "{colors.item-icon-dark}"
    textColor: "{colors.on-surface-dark}"
    rounded: "{rounded.md}"
  accent-on-dark:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.primary}"
    typography: "{typography.call-to-action}"
  inverse-label:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.on-primary}"
  destructive-on-dark:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.destructive}"
    typography: "{typography.body-emphasized}"
  separator-light-swatch:
    backgroundColor: "{colors.separator-light}"
    textColor: "{colors.on-primary}"
  separator-dark-swatch:
    backgroundColor: "{colors.separator-dark}"
    textColor: "{colors.on-primary}"
---

# Cubby Visual Contract

## Overview

Cubby should feel warm, calm, and quietly capable: an iPhone-native utility softened by cream canvases, tactile item artwork, and a distinctive editorial serif. Keep information easy to scan, let item photos and emoji carry personality, and avoid ornamental density. This file is the agent-facing visual contract; `docs/design-system.md` is the implementation and governance guide.

## Colors

Use `CubbyDesign.Palette` in SwiftUI. `canvas`, `homeCanvas`, and `itemIconBackground` are adaptive asset colors represented above by explicit light and dark tokens. System-derived surfaces, text, separators, accent, and destructive colors must remain adaptive in code; the hex values document their iOS reference appearances. Reserve the accent for interaction and selection, and never use color as the only state cue.

## Typography

Use `CubbyDesign.Typography` roles; never construct shared custom fonts in feature views. Awesome Serif supplies branded display and navigation hierarchy. Circular Std supplies readable content, labels, metadata, and actions. Every SwiftUI role is relative to a system text style and must scale with Dynamic Type; the front-matter sizes are the default reference sizes.

## Layout

Build from the 4, 8, 12, 16, 20, 24, 32, and 40 spacing scale. In this iPhone contract, CSS-style `px` dimensions map 1:1 to SwiftUI points. Interactive controls require at least 44 points in both dimensions. Prefer responsive containers, a maximum readable width of 720 points where relevant, and a fixed aspect-ratio media viewport when Dynamic Type should not distort imagery.

## Elevation & Depth

Depth is restrained. Flat surfaces have no shadow; cards use black at 5% opacity with radius 8 and y-offset 4; raised surfaces use black at 8% opacity with radius 16 and y-offset 8. Use `cubbySurface(_:)` so fill, stroke, corner radius, and elevation remain coordinated. Native lists, forms, sheets, and materials take precedence over custom elevation.

## Shapes

Corners are continuous and friendly: 8 points for compact controls, 12 for standard controls, 18 for cards, and 24 for prominent raised or media surfaces. Capsules are appropriate for tags and compact status treatments. Use hairline 0.5-point strokes, standard 1-point strokes, and emphasized 2-point strokes only through semantic design APIs.

## Components

Item rows pair a 48-point emoji or photo anchor with a clear title and secondary location context. Tags wrap naturally using `WrappingHStackLayout`; delete and suggestion actions retain 44-point hit regions. Onboarding remains scrollable and keyboard-aware at accessibility sizes. Item media keeps a responsive aspect-ratio viewport. Paywall geometry may retain its documented campaign-style palette, but its typography, accessibility, and interaction sizing still follow shared foundations. Motion uses `quick`, `standard`, or `emphasized` intent tokens and resolves immediately when Reduce Motion is enabled.

## Do's and Don'ts

Do use semantic typography, palette, spacing, radius, stroke, surface, and motion APIs. Do preview loading, empty, error, dark, accessibility-text, and Reduce Motion states. Do use native controls and stable accessibility labels. Don't duplicate asset names, font names, shared timing curves, or reusable dimensions in feature code. Don't scale hit targets down to match visible artwork. Don't introduce a token for one-off media geometry or campaign art unless it establishes a reusable product rule.
