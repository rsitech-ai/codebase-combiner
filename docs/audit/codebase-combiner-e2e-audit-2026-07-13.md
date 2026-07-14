# App E2E Audit Report: Codebase Combiner

## Outcome

- Audit date: 2026-07-14. The filename retains the implementation-plan date.
- Audited artifact: `dist/app-store/Codebase Combiner E2E.app`, built from the Release product and signed with `Packaging/AppStore/AppStore.entitlements`.
- Audited platform: macOS 27 beta with a macOS 13 deployment target.
- Readiness label: **interaction-clean for the audited local core workflow, with explicit blocked variants**.
- Release boundary: this is not an App Store or release-candidate claim. Distribution signing, notarization, upload, and owner-account work remain separate gates.

The final sandboxed host completed the primary workflow: real open panel, fixture scan, selection, copy, save panel, relaunch recovery, menus, Settings, and repeated pane transitions. The audit also found a macOS 27 beta AppKit constraint crash. The final implementation avoids the crashing structural split/inspector and stateful toolbar-preference transitions; one exact sandbox PID then survived 20 combined pane transitions with empty stderr and no new crash report.

## Isolation And Process Ownership

- The E2E bundle identifier is `com.s1korrrr.codebasecombiner.e2ehost`, distinct from production.
- Effective signed entitlements were inspected before UI work. `com.apple.security.app-sandbox` and `com.apple.security.files.user-selected.read-write` were both `true`.
- Preferences use the E2E app's standard sandbox preferences. Recovery storage resolved inside `~/Library/Containers/com.s1korrrr.codebasecombiner.e2ehost/Data/Library/Application Support/Codebase Combiner/`.
- The only opened workspace was the disposable fixture copied to `/private/tmp/CodebaseCombinerE2EFixture`.
- `script/build_and_run.sh` launches the exact executable directly, captures `$!`, verifies its full command twice, and terminates/reaps only that owned PID. It contains no `pgrep`, `pkill`, or application-name launch/discovery.
- `--verify` owns its launch through cleanup. `--e2e` is a foreground wrapper and removes its PID file only after the child exits or is reaped.
- Clipboard tests backed up and restored the existing pasteboard. Saved output stayed under `/private/tmp`.

## Runtime Corrections

### Structured outcomes and telemetry

`WorkspaceStore.scan` now returns one explicit result: accepted metadata, invalid-size rejection, failure, or stale completion. `AppController` records that returned result instead of inferring success from mutable state. `OutputStore` and `AppController` share an injected typed telemetry recorder; behavioral tests prove that telemetry carries counts and outcomes without payloads or paths.

The sandboxed live workflow emitted metadata-only events for scan start, accepted counts, recovery save counts, current copy length, and recovery load. No log event exposed source, prompt, root, or destination content.

### macOS 27 pane crash

Three sandbox runs exposed the same AppKit update-constraints failure through different SwiftUI hosts:

1. Nested split view plus sidebar restore.
2. Native `.inspector` after a loaded-workspace toggle.
3. A stateful sidebar toolbar item, whose crash backtrace named `AppKitToolbarStrategy.updatedVendedItems`.

The retained design keeps both panes mounted at constant size and shows or hides them with transform, opacity, hit testing, and accessibility state. Toolbar pane controls are static buttons with static labels/help, so pane changes do not mutate toolbar preferences. The focused tests guard against `NavigationSplitView`, `HSplitView`, native `.inspector`, geometry callbacks, and stateful pane toolbar toggles.

Final runtime proof used sandbox PID `25766`: after the real fixture loaded, five cycles of inspector hide, sidebar hide/show, and inspector restore completed. The automation checked the foreground wrapper PID file after every action and would stop before any relaunch. The same exact command remained alive after a two-second stability check, stderr was zero bytes, and no new crash report appeared.

## Scenario Matrix

| Surface                | Scenario                                                     | Result                                                                                                  | Status                                            |
| ---------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| Launch                 | Signed sandbox host                                          | Effective sandbox and user-selected read/write entitlements verified before launch                      | Verified                                          |
| Workspace              | Real `NSOpenPanel`                                           | Selected only `/private/tmp/CodebaseCombinerE2EFixture`                                                 | Verified                                          |
| Scan                   | Default fixture                                              | Accepted README and Swift source; reported two skipped files without paths                              | Verified                                          |
| Copy                   | Current and recovered output                                 | Payload lengths matched; original clipboard restored                                                    | Verified                                          |
| Save                   | Real `NSSavePanel`                                           | Wrote the 639-byte synthetic output only under `/private/tmp`                                           | Verified                                          |
| Recovery               | Concealed relaunch, reveal/hide, Copy Last                   | Draft loaded from E2E container and stayed concealed until explicit reveal                              | Verified by AX/runtime                            |
| Recovery               | Clear confirmation Cancel                                    | Safe default canceled and preserved the draft                                                           | Verified                                          |
| Recovery               | Confirm destructive clear                                    | Store behavior is covered by tests; final UI destructive click was not performed                        | Blocked                                           |
| Panes                  | Inspector and sidebar                                        | Five combined cycles, 20 transitions, one exact PID, empty stderr                                       | Verified after fix                                |
| Menus                  | File, Edit, View, Support                                    | Canonical actions and enablement inspected through real menus                                           | Verified                                          |
| Settings               | General and Support                                          | Standard Settings scene opened and both tabs were inspected                                             | Verified                                          |
| Support                | External browser destination                                 | App action launched the browser; destination inspection was unavailable                                 | Blocked beyond launch                             |
| Appearance             | Current dark appearance                                      | Final sandbox screenshots inspected                                                                     | Verified                                          |
| Accessibility variants | Light, increased contrast, Reduce Motion, larger system text | Would require system-setting changes outside this audit's authority                                     | Blocked                                           |
| Window                 | Compact loaded workflow                                      | Runtime and screenshot remained usable with all three work areas reachable                              | Verified                                          |
| Window                 | 1440x900 outer frame                                         | Sandbox preference recorded exact frame `36 24 1440 900`; Computer Use normalized the image to 1229x768 | Runtime verified; native-pixel screenshot blocked |

## Screenshot Evidence

- `docs/audit/codebase-combiner-e2e-2026-07-14/01-sandbox-compact-loaded.png` shows the synthetic `/private/tmp` fixture, scan summary, selected counts, and output actions after the final pane fix.
- `docs/audit/codebase-combiner-e2e-2026-07-14/02-sandbox-wide-recovery-concealed.png` shows the exact-frame wide run with recovery metadata concealed. The capture service normalized the file to 1229x768, so it is not claimed as native 1440x900 pixel evidence.
- No retained screenshot contains `/Users/s1kor` or user source content.
- The wide recovery body is concealed by product behavior. Concealment/redaction is privacy evidence only; it is not cited as visual proof of the hidden payload.

## Automated Gates

| Check                 | Command                                                                         | Result                                               |
| --------------------- | ------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Swift formatting      | `cd SwiftExplorerApp && swiftformat --lint .`                                   | 43 files checked; 0 require formatting               |
| Swift tests           | `cd SwiftExplorerApp && swift test`                                             | 86 tests; 0 failures                                 |
| Release warnings      | `cd SwiftExplorerApp && swift build -c release -Xswiftc -warnings-as-errors`    | Passed                                               |
| Node behavior         | `npm test`                                                                      | 4 tests; 0 failures                                  |
| Node lint             | `npm run lint`                                                                  | Passed                                               |
| Repository formatting | `npm run format:check`                                                          | Passed                                               |
| Script contract       | `script/tests/build_and_run_contract_test.sh`                                   | Passed                                               |
| Script syntax         | `bash -n script/build_and_run.sh Packaging/AppStore/build_app_store_package.sh` | Passed                                               |
| Package               | `Packaging/AppStore/build_app_store_package.sh --skip-signing`                  | Passed with strict signature verification            |
| Installed-app smoke   | `./script/build_and_run.sh --verify`                                            | Exact PID launched, verified, terminated, and reaped |

## TDD And Failure Evidence

- Telemetry/outcome RED: missing typed recorder and `WorkspaceScanOutcome`; focused GREEN ended with 18 tests and no failures.
- Inspector-host RED: source still used native `.inspector`; GREEN removed native inspector and nested split usage.
- Constant-layout RED: hidden panes changed layout width; GREEN retains constant pane size and changes only transform/accessibility state.
- Toolbar RED: sidebar and inspector used stateful toolbar toggles; GREEN uses static controls.
- Wide-frame RED: restored window state overrode requested E2E geometry; GREEN adds an E2E-only exact outer-frame policy while production ignores the environment.
- Crash reports `030709`, `031512`, `032005`, and `032349` are retained only as local diagnostic evidence and are not product artifacts.

## Scope Boundary

No signing identity, provisioning profile, notarization, upload, purchase, public write, user-source mutation, or system-setting mutation was performed. Final readiness remains limited to the audited local sandbox workflow.
