# Mac App Store Release Checklist: Codebase Combiner

Use "verified", "blocked", or "not applicable" for each item. Add evidence.

## Account And App Record

| Item                                   | Status   | Evidence                                                                                   |
| -------------------------------------- | -------- | ------------------------------------------------------------------------------------------ |
| Apple Developer Program team confirmed | blocked  | User has membership, but distribution signing identity is not installed locally.           |
| Bundle identifier registered           | blocked  | Required bundle ID: `com.s1korrrr.codebasecombiner`; must be confirmed in Apple Developer. |
| App Store Connect app record exists    | blocked  | Needs macOS app record for `Codebase Combiner`.                                            |
| Version and build numbers set          | verified | `Packaging/AppStore/build_app_store_package.sh` defaults to version `0.1.0`, build `1`.    |

## Signing And Sandbox

| Item                                            | Status   | Evidence                                                                      |
| ----------------------------------------------- | -------- | ----------------------------------------------------------------------------- |
| Distribution signing configured                 | blocked  | Local keychain previously showed only Apple Development identity.             |
| Provisioning profile valid                      | blocked  | No local Mac App Store provisioning profile verified.                         |
| App Sandbox enabled                             | verified | `Packaging/AppStore/AppStore.entitlements`.                                   |
| Entitlements minimized and reviewed             | verified | Sandbox plus user-selected read/write only.                                   |
| Hardened runtime/distribution settings reviewed | blocked  | Final distribution signing path requires Apple signing assets.                |
| `codesign` inspection captured                  | verified | Local ad-hoc bundle validation captures entitlements under `dist/app-store/`. |

## Privacy

| Item                                        | Status   | Evidence                                                                                 |
| ------------------------------------------- | -------- | ---------------------------------------------------------------------------------------- |
| Data collection inventory complete          | verified | Local source files, preferences, and last generated payload only; no network collection. |
| Privacy manifest present where required     | verified | `Packaging/AppStore/PrivacyInfo.xcprivacy`.                                              |
| Privacy labels drafted in App Store Connect | blocked  | Must be entered in App Store Connect.                                                    |
| Permission purpose strings reviewed         | verified | No protected camera/mic/location/contact permissions used.                               |
| Third-party SDK privacy reviewed            | verified | Swift app has no third-party SDK dependencies.                                           |
| Logs exclude sensitive data                 | verified | No persistent raw-content logging is implemented.                                        |

## Product Quality

| Item                             | Status   | Evidence                                                                                             |
| -------------------------------- | -------- | ---------------------------------------------------------------------------------------------------- |
| Unit tests pass                  | verified | `cd SwiftExplorerApp && swift test` passed 8 tests on 2026-06-29.                                    |
| Integration tests or mocks pass  | verified | Tree loader and draft store temp-directory file-system tests passed.                                 |
| Release build/archive succeeds   | verified | `Packaging/AppStore/build_app_store_package.sh --skip-signing` passed.                               |
| Clean launch of release artifact | verified | `./script/build_and_run.sh --verify` launched `CodebaseExplorerApp`.                                 |
| Primary workflow smoke passed    | partial  | Launch/release smoke passed; folder-picker manual scan smoke still recommended.                      |
| Crash/log check after smoke      | verified | Launch smoke completed and app process was stopped without crash evidence.                           |
| Accessibility pass               | partial  | Reduce Motion respected; final VoiceOver/manual pass still needed.                                   |
| Light/Dark/Reduce Motion checked | partial  | Code supports semantic colors and Reduce Motion; final visual pass still needed.                     |
| Performance smoke checked        | partial  | Release bundle build/launch passed; large real-workspace timing still recommended before submission. |

## App Store Assets

| Item                                         | Status         | Evidence                                                                                  |
| -------------------------------------------- | -------------- | ----------------------------------------------------------------------------------------- |
| App icon complete                            | verified       | Packaging script generates `.icns` from `assets/icon.jpg`.                                |
| Screenshots prepared                         | partial        | Current screenshot: `docs/screenshots/macos-app.png`; final App Store sizes still needed. |
| App name/subtitle/description/keywords       | blocked        | Needs final App Store Connect copy.                                                       |
| Category and age rating                      | partial        | Category set to Developer Tools; age rating must be completed in App Store Connect.       |
| Support URL                                  | partial        | Support link exists; final public support/privacy URLs must be decided.                   |
| Marketing URL, if used                       | not applicable | Not required for v1.                                                                      |
| Review notes and demo credentials, if needed | partial        | No demo credentials needed; review notes should mention local-only folder access.         |

## Release Decision

- Current readiness label: release-candidate local app ready; App Store submission blocked on account/assets/signing/metadata.
- Remaining blockers: Apple distribution identity, installer identity, provisioning profile, App Store Connect app record, final metadata/screenshots/privacy labels.
- Submission owner: user with Apple Developer/App Store Connect access.
- Next action: install signing assets and run `Packaging/AppStore/build_app_store_package.sh` without `--skip-signing`.
