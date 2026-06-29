# Production Plan: Codebase Combiner

## Product Brief

- Target user: developers who need to package selected code files into one prompt-ready payload.
- Primary job: choose a workspace, filter/select files, add optional instructions, copy or save the combined output.
- Core workflow: pick folder -> scan -> refine selection/filters -> copy or save combined payload -> recover last ready payload later if needed.
- Business model: free developer tool with optional support link.
- Supported macOS versions: macOS 13+.
- Offline behavior: fully local; no network is required for scanning, combining, copying, saving, or restoring the last payload.
- Data handled: user-selected local source files, prompt prefix text, preferences, and the last generated combined payload.
- Privacy posture: local-first, no tracking, no analytics, no collected data; saved payload is user content stored locally in Application Support.
- V1 scope: SwiftPM macOS app, native UI, settings, support link, persistence, tests, local App Store bundle validation.
- Explicitly out of scope: cloud sync, account system, AI model calls, paid unlocks, automatic upload to App Store Connect.

## Architecture

- Scene model: `WindowGroup` for the main app plus `Settings` and a dedicated settings window.
- Window roles: primary workspace window and settings utility window.
- Layout model: sidebar tree plus main prompt/controls/selection/stat surface.
- State ownership: view state in `ContentView`, durable preferences through `@AppStorage`, durable last payload through `ClipboardDraftStore`.
- Persistence: preferences in UserDefaults, last ready combined payload as atomic JSON under Application Support.
- Services: `TreeLoader`, `TokenEstimator`, `CombinedOutputBuilder`, `ClipboardDraftStore`.
- App Intents / Foundation Models / advanced capabilities: not used in v1.
- Folder/module structure: `Models/`, `Services/`, `Support/`, `Views/`, and XCTest targets.

## Build And Run

- Project type: SwiftPM executable plus VS Code extension package.
- Build command: `cd SwiftExplorerApp && swift build`.
- Run command: `cd SwiftExplorerApp && swift run`.
- `script/build_and_run.sh` status: available; `./script/build_and_run.sh --verify` builds the local App Store-style bundle and verifies launch.
- Codex Run action status: `.codex/environments/environment.toml` points Run to `./script/build_and_run.sh --verify`.

## Design System

- Native structures: SwiftUI sidebar list, settings scene, forms, segmented picker, standard buttons, macOS materials.
- Adaptive states: empty folder, scanning, loaded, no selection, copy toast, saved last payload, settings.
- Visual style: semantic colors, regular materials, compact desktop controls, subtle hover and surface elevation.
- Motion rules: state-change animations are short and respect Reduce Motion.
- Accessibility requirements: labeled controls, keyboard shortcuts for choose/refresh/copy/save, visible selection and focus-compatible native controls.
- Empty/loading/error/offline/permission states: empty and loading states are visible; scan/save errors surface in the status label; offline is normal operation.

## Test Strategy

- Unit tests: token estimator, tree loader, combined output builder, clipboard draft store.
- Integration tests or mocks: file-system backed tree loader and draft-store tests use temporary directories.
- UI/manual smoke: `./script/build_and_run.sh --verify` and packaged `.app` launch smoke.
- Release smoke: `Packaging/AppStore/build_app_store_package.sh --skip-signing`, plist validation, codesign entitlement inspection.
- Commands: `swiftformat --lint .`, `swift build`, `swift test`, `npm test`, `npm run lint`, `npm run format:check`.

## Observability

- Logger subsystem: `com.s1korrrr.codebasecombiner`.
- Categories: lifecycle, scan, export, persistence.
- Key lifecycle/action events: app launch, scan start/success/failure, copy/save actions, draft restore/save/clear failures.
- Sensitive logging exclusions: do not log raw file contents, combined payload text, secrets, or private paths in persistent logs.

## App Store Readiness

- Bundle ID: `com.s1korrrr.codebasecombiner`.
- Signing team: blocked on installing distribution certificates/provisioning profile.
- Sandbox/entitlements: App Sandbox and user-selected read/write.
- Privacy manifest: present; declares UserDefaults reason, no tracking, no collected data.
- Privacy labels: should be no tracking/no collected data unless future telemetry or networking is added.
- Assets: app icon generated from `assets/icon.jpg`; screenshot exists at `docs/screenshots/macos-app.png`.
- Metadata: README/INSTALL contain packaging notes; App Store Connect metadata still needs final copy and URLs.
- Review notes: app is local-first and needs no demo account.
- Known blockers: App Store Connect app record, Mac App Store distribution identity, installer identity, provisioning profile, final metadata/screenshots.

## Iteration Log

| Date       | Gate               | Change                                                                | Verification                                                                     | Next blocker              |
| ---------- | ------------------ | --------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ------------------------- |
| 2026-06-29 | Production quality | Added file-backed last-ready-payload persistence and restore/copy UI. | `swift test` passed 8 tests; `npm test`; `npm run lint`; `npm run format:check`. | App Store signing assets. |
| 2026-06-29 | Build/run          | Added `script/build_and_run.sh --verify` and Codex Run action.        | `./script/build_and_run.sh --verify` launched packaged app.                      | None for local smoke.     |
