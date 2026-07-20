# Codebase Combiner open-source release-readiness audit — 2026-07-20

## Executive outcome

**NOT READY FOR PUBLICATION**

The repository-side remediation in this audit is complete and the full local quality, packaging, and release-contract matrix is green. Publication remains a no-go because the requested dedicated security scan was explicitly omitted, GitHub private vulnerability reporting and `main` protection are disabled, the release environment is not provisioned, no valid Apple signing identity is available locally, no signed/notarized production artifact exists, and the declared macOS 13 runtime floor has not been exercised on that OS version.

This verdict does not block merging the repository hardening. It blocks representing the project as fully publication-ready or issuing an official release.

## Scope and authority

- Audited baseline: `main` at `7f278ffc20bb21d40a5d3f0fae262ad8863d39da`.
- Surfaces: VS Code extension, macOS SwiftUI app, release scripts/workflows, public documentation, licensing notices, and live GitHub repository settings.
- Authorized external write: push the completed hardening to `main`.
- Explicit exclusion: no dedicated security scan was run.
- Not authorized or not possible in the original audit pass: GitHub settings changes, Apple signing/notarization, release/tag publication, App Store submission, or transfer to another owner/publisher. A later owner-authorized follow-up transferred the repository to `rsitech-ai`; that result is recorded in the post-audit addendum below.

## Repository assessment

| Area                           | Result        | Evidence                                                                                                                                                                 |
| ------------------------------ | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Node extension behavior        | PASS          | 30 tests passed; lint and formatting passed.                                                                                                                             |
| Swift app behavior             | PASS          | 126 tests passed; production build passed with warnings treated as errors.                                                                                               |
| Dependency integrity           | PASS          | 379 registry signatures and 25 attestations verified; npm reported 0 vulnerabilities. This is dependency-audit evidence, not a substitute for the omitted security scan. |
| VSIX packaging                 | PASS          | Exact expected artifact and embedded name/version/publisher verified; stale root artifacts are rejected.                                                                 |
| Developer ID contracts         | PASS          | Build, verification, resume, and mocked notarization contracts passed. No production Apple credentials or notarization were used.                                        |
| App Store packaging contracts  | PASS          | Provisioning-profile and signed-package contract harnesses passed. No App Store upload was performed.                                                                    |
| Public docs and privacy claims | PASS          | Unsupported release, runtime, deletion, layout, and control-label claims were corrected.                                                                                 |
| Dedicated security scan        | NOT PERFORMED | Explicitly excluded by request.                                                                                                                                          |
| Official release evidence      | BLOCKED       | No tag/release, signing identity, notarized artifact, release environment, or macOS 13 runtime proof.                                                                    |

## Changes made

- The VS Code extension now suggests `combined_code.md` when Markdown is selected and the untouched default filename is still configured, while preserving custom filenames.
- Swift directory traversal now enumerates immediate children incrementally and stops at the traversal boundary instead of materializing an unbounded directory listing first.
- Developer ID source tags are bound to the manifest marketing version in both build and verification paths, with a behavioral contract for mismatched tags.
- The macOS release workflow no longer relies on Bash 4 uppercase expansion on the macOS runner.
- The VSIX inventory contract selects one exact package identity, inspects embedded manifest identity, and rejects stale/ambiguous root artifacts.
- SwiftFormat is pinned consistently to CI version 0.61.1, including the repository's intentional `redundantSendable` rule exception.
- README, installation, release, privacy, review, issue-template, changelog, and layout documentation now match verified behavior and current release state.
- `assets/icon.png` now contains PNG data instead of JPEG data with a `.png` extension; the visual design was preserved.
- Security guidance no longer points contributors to a disabled private advisory endpoint and explicitly records the missing private intake as a publication blocker.

## Validation evidence

The following gates passed in the release-readiness worktree:

```text
npm run format:check
npm run lint
npm test                                      # 30/30 passed
npm audit signatures                          # 379 signatures, 25 attestations
npm audit --omit=dev                          # 0 vulnerabilities
npm audit                                     # 0 vulnerabilities
npm run package
/bin/bash script/tests/vsix_inventory_test.sh

SwiftFormat 0.61.1 --lint .                   # 0/46 require formatting
cd SwiftExplorerApp && swift test             # 126/126 passed
cd SwiftExplorerApp && swift build -c release -Xswiftc -warnings-as-errors
./script/build_and_run.sh --verify             # exact production PID launched, verified, terminated, and reaped

/bin/bash script/tests/build_and_run_contract_test.sh
/bin/bash script/tests/open_source_release_contract_test.sh
/bin/bash Packaging/DeveloperID/tests/run_tests.sh
/bin/bash Packaging/AppStore/tests/validate_provisioning_profile_test.sh
find . -type f -name '*.sh' ... | xargs -0 -n1 /bin/bash -n
```

YAML parsing, plist/privacy-manifest linting performed by the contracts, `git diff --check`, DMG mounting, code-signature structure, checksums, SBOM/symbol inventory, and mocked notarization evidence also passed.

## Security and privacy findings

- **BLOCKER — security assurance:** the dedicated security scan requested by the original release brief was not run, by explicit instruction. No statement in this audit should be interpreted as a completed source-security assessment.
- **BLOCKER — vulnerability intake:** live GitHub private vulnerability reporting returned `enabled: false`. The public policy now reports that truth and forbids public disclosure, but a functioning private intake must be enabled before publication.
- **HIGH — branch integrity:** the live repository has neither `main` branch protection nor a ruleset. Required checks and review protections are therefore not enforced by GitHub.
- **HIGH — release credentials:** the live repository has zero release environments and the local machine reports zero valid code-signing identities. Production signing/notarization cannot be proven from this environment.
- **PASS — privacy claims:** documentation now covers both the sandboxed macOS app and the local VS Code extension, and no longer promises that uninstalling the app deletes saved output or application data.
- **PASS — dependency audit:** npm vulnerability and signature checks are green. They cover known dependency advisories and registry provenance only.

## Licensing and provenance

- Repository license: MIT.
- The packaged VSIX and macOS release contracts include the license and third-party notices.
- Shipped Node runtime dependencies are represented in `THIRD_PARTY_NOTICES.md` and the package lock.
- **Owner confirmation required:** retain evidence that the icon and all public artwork are original or licensed for redistribution.
- **Owner/legal confirmation required:** decide whether the copyright alias in `LICENSE` should remain `s1kor` or use the maintainer's legal/public name. This audit does not make that legal identity choice.
- **Repository transfer complete:** the GitHub repository is owned by `rsitech-ai`. The VS Code Marketplace publisher remains `s1korrrr` because Marketplace publisher identity is a separate release/account boundary.

## Live GitHub state (post-audit transfer addendum)

Verified on 2026-07-20 for `rsitech-ai/codebase-combiner` after preserving `main` at `c999df9e39633c8f18e7ec328e0412b6842a82aa` through the transfer:

- Public repository; default branch `main`; Issues enabled.
- No branch protection and no repository rulesets.
- Private vulnerability reporting disabled.
- No release environments.
- No tags and no GitHub Releases.
- Existing repository description and topics are present and aligned with the product.

In the later owner-authorized follow-up, the repository ownership and website settings were changed from `s1korrrr` to the canonical `rsitech-ai` repository; other listed GitHub settings were not changed.

## GO / NO-GO matrix

| Gate                                  | Decision | Required next action                                                                                                              |
| ------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Merge repository hardening to `main`  | GO       | Push the verified commit and require hosted CI/CodeQL to pass.                                                                    |
| Publish source as an official release | NO-GO    | Complete a dedicated security assessment and enable private vulnerability reporting.                                              |
| Publish a VSIX                        | NO-GO    | Confirm publisher ownership, provenance, version/tag plan, and hosted checks for the exact commit.                                |
| Publish a Developer ID DMG            | NO-GO    | Provision protected release credentials, build from a signed `macos-v0.1.0` tag, notarize, staple, and verify the exact artifact. |
| Submit to App Store Connect           | NO-GO    | Provide signing/provisioning/App Store Connect evidence and complete runtime/review validation.                                   |

## Exact next actions

1. Enable GitHub private vulnerability reporting and update the policy link only after the endpoint is functional.
2. Add a `main` ruleset requiring pull requests and the repository's CI/CodeQL checks; retain an owner recovery path.
3. Run and triage a dedicated security scan against the exact release commit.
4. Confirm icon/artwork provenance, license attribution identity, and the separate VS Code Marketplace publisher strategy. GitHub repository ownership is resolved as `rsitech-ai`.
5. Validate the macOS app on macOS 13 and record launch, scan, save, recovery, sandbox, and accessibility evidence.
6. Provision the protected `release` environment and Apple Developer ID/notarization secrets; keep certificate material out of repository logs and artifacts.
7. Create and sign the release tag only after all blockers close, then verify the produced checksums, SBOM, symbols, signatures, notarization ticket, and hosted workflow provenance before publication.
