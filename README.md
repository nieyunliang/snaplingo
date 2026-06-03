# Snaplingo

Snaplingo is a native macOS menu bar app that captures screen regions or windows, then overlays Chinese translations in an in-place screenshot editor using on-demand Vision OCR.

## What Is Implemented

- Menu bar app shell.
- Unified `Option + A` screenshot shortcut.
- Screenshot overlay with mouse magnifier, drag-to-capture regions, click-to-capture highlighted windows, and `Esc` cancel.
- In-place screenshot editor with arrow, rectangle, and circle annotations, undo, inline Chinese translation, copy, PNG save, finish, and close actions.
- Inline translation replaces foreign-language OCR blocks inside the image with readable Chinese overlays.
- Screen recording permission check and settings shortcut.
- Vision OCR with configurable recognition languages.
- Offline dictionary translation, glossary support, and translation memory.
- DeepSeek-compatible Chat Completions translation with Simplified Chinese output and style settings.
- API key storage in local app preferences.
- Captured images stay in memory unless the user explicitly saves a PNG from the in-place editor.
- Launch-at-login toggle through `SMAppService`.

## Run

```bash
./scripts/run-app.sh
```

The script builds and launches a project-local `Snaplingo.app` bundle with the
same `com.snaplingo.app` bundle identifier used by packaged builds. This gives
macOS a consistent app bundle for Screen Recording permission.

Avoid `swift run` for screenshot workflows. It launches an unbundled SwiftPM
executable with a different identity, so permission granted to `Snaplingo.app`
does not apply to that process. The app appears in the macOS menu bar as
`Snaplingo`.

## Package

Local packaging defaults to ad-hoc signing:

```bash
./scripts/build-dmg.sh
```

For release builds, provide a stable Developer ID Application certificate:

```bash
CODESIGN_IDENTITY="Developer ID Application: Example (TEAMID)" ./scripts/build-dmg.sh
```

An ad-hoc signature identifies one specific build. After replacing an installed
ad-hoc build, macOS may still display `Snaplingo` as enabled under Screen
Recording while requiring permission to be granted again for the new build.

## Check

```bash
swift build
swift test
bash -n scripts/run-app.sh
bash -n scripts/build-dmg.sh
```

## Notes

- macOS must grant Screen Recording permission before screenshots can be captured.
- After granting Screen Recording permission to `Snaplingo`, restart the app once before capturing again.
- Screenshot translation is triggered manually from the in-place toolbar and always renders Chinese inside the captured image.
- DeepSeek translation requires an API key in Settings. Offline dictionary translation does not.
- `swift test` runs the XCTest suite locally.
- The capture backend uses ScreenCaptureKit where available. Automated screen capture smoke tests still need a permission-gated harness because macOS Screen Recording consent cannot be granted headlessly.
