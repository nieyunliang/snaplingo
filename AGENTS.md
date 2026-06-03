# AGENTS.md

## Scope

These instructions apply to the entire repository.

## Project Overview

Snaplingo is a native macOS menu bar screenshot translator built with Swift Package Manager. It captures screenshots, runs OCR, translates text, and presents results in floating macOS UI surfaces.

The app targets macOS 14 and is declared in `Package.swift` as a Swift tools version 6.0 package with:

- Executable target: `Sources/Snaplingo`
- Test target: `Tests/SnaplingoTests`
- App resources: `Sources/Snaplingo/Resources`

## Source of Truth

Keep this file aligned with the current implementation. When repository documentation differs from the source code, treat the current code and tests as the source of truth. Document functionality as implemented only when it exists in the current source and tests.

## Current Functional Baseline

The current app is centered on an in-place screenshot workflow:

- Menu bar app with Screenshot, Settings, and Quit actions.
- Global screenshot hotkey: `Option + A`.
- Unified screenshot selection overlay with drag-to-capture regions, click-to-capture highlighted windows, mouse magnifier, and `Esc` cancel.
- ScreenCaptureKit-based region and window capture, with Retina and multi-display coordinate handling.
- In-place floating screenshot editor with arrow, rectangle, and circle annotations, undo, inline translation toggle, PNG save, finish, and close actions.
- Vision OCR with configurable recognition language codes. Fast recognition is tried first and low-confidence or empty results fall back to accurate recognition.
- Inline Chinese translation over OCR text blocks. OCR and translation run only after the user clicks the translation action.
- Translation options include DeepSeek-compatible Chat Completions, an offline dictionary/glossary replacement MVP, and local translation memory.
- Translation style, OCR languages, provider, DeepSeek model/base URL/API key, glossary, translation memory, window shadow capture, and launch-at-login are configurable in Settings.
- Translation memory is stored as JSON in the user Application Support directory.
- DeepSeek API keys are currently stored in local `UserDefaults`, not Keychain.

## Repository Layout

- `Sources/Snaplingo/`: App source, including menu bar coordination, capture services, OCR, translation, settings, annotation, inline editor UI, clipboard, PNG export, launch-at-login, and permissions.
- `Tests/SnaplingoTests/`: XCTest coverage for settings, translation request behavior, translation memory, OCR retry strategy, inline translation layout, rendering/export helpers, and geometry.
- `scripts/`: Local run, packaging, and resource generation scripts.
- `Packaging/`: App packaging metadata and resources.
- `docs/`: Product and feature documentation.
- `dist/`: Built distribution artifacts. Treat as generated output unless the task is explicitly about packaging or release artifacts.
- `.build/`: SwiftPM build output. Do not edit manually.

## Common Commands

Run the app:

```bash
./scripts/run-app.sh
```

This is the recommended way to test screenshot workflows because it builds and launches a local `Snaplingo.app` bundle with the app bundle identifier used by packaged builds. macOS Screen Recording permission is bundle-identity sensitive.

Run the SwiftPM executable directly:

```bash
swift run
```

Use `swift run` for quick executable checks only. It launches an unbundled process, so Screen Recording permission granted to `Snaplingo.app` may not apply.

Build:

```bash
swift build
```

Run tests:

```bash
swift test
```

Check shell scripts:

```bash
bash -n scripts/run-app.sh
bash -n scripts/build-dmg.sh
```

Recommended verification after code changes:

```bash
swift build
swift test
bash -n scripts/run-app.sh
bash -n scripts/build-dmg.sh
```

## Development Notes

- Prefer the existing Swift/AppKit/SwiftUI patterns already present in `Sources/Snaplingo`.
- Keep UI-affecting state and app coordination on the main actor when interacting with AppKit, SwiftUI, or observable settings.
- Keep unit tests isolated with temporary directories or dedicated `UserDefaults(suiteName:)` instances.
- Do not hard-code API keys or secrets. DeepSeek API keys are currently persisted through `UserDefaults`; moving them to Keychain would be a privacy/security hardening change that should update tests and docs together.
- Be careful around macOS permission flows. Screen Recording permission cannot be granted headlessly, so automated screenshot smoke tests need a permission-gated harness.
- The capture backend uses ScreenCaptureKit where available.
- Treat `.build/`, `.swiftpm/`, `.DS_Store`, `dist/`, and generated app bundles/DMGs as generated output unless the task is explicitly about build metadata, packaging, or release artifacts.

## Testing Guidance

- Add or update focused XCTest coverage for behavior changes in services, model logic, geometry, parsing, persistence, and translation request construction.
- For UI-only changes, prefer tests around extracted state, formatting, geometry, or rendering helpers when practical.
- If a test depends on Vision OCR or screen capture permissions, document the limitation clearly and keep the default test path suitable for local `swift test`.

## Change Hygiene

- Do not modify `.build/`, `.swiftpm/`, `.DS_Store`, or generated distribution artifacts unless the user explicitly asks for build metadata or packaging output.
- Keep documentation in sync when changing user-visible behavior, shortcuts, settings, capture modes, translation behavior, or packaging commands.
- Keep changes narrowly scoped. Avoid broad refactors unless they are necessary for the requested work.
