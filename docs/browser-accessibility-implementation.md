# Browser accessibility recovery

## Problem and evidence

Dia can expose its toolbar while its tab's web accessibility tree is missing or still loading. The current browser list omits `company.thebrowser.dia`, so Dia misses browser-specific recovery and current-browser URL handling. A failed web-content read can also put the window in a permanent skip set. The command loop detects several navigations only when the window title changes, which misses same-title tab changes and single-page app navigation.

These are confirmed code paths. We do not have a live accessibility dump of the user's Railway dashboard, so they are not proof that Railway's project cards are otherwise exposed correctly.

## Implementation

1. Put browser recognition, navigation refresh decisions, and missing-content retry deadlines in a platform-independent core module. Add regression tests before changing their current behavior.
2. Recognize Dia and Arc by bundle identifier. Known Chromium browsers request accessibility even when framework helper discovery fails. Keep framework discovery for other Chromium/Electron apps.
3. Replace the permanent missing-window set with a ten-second cooldown for non-browser native windows. Browsers and loading pages always retry. Clear successful and expired entries under the existing lock.
4. After clicks, Return, back, tab switches, and menu actions, wait for page observations to settle without requiring a title change or an immediately visible effect. Compare labels, values, URLs, structure, and loading state rather than node count alone. Keep waits bounded and cancellable.
5. Compare complete offered-target descriptions between command cycles so unchanged IDs do not hide a changed label or value. Apply page settling to planned clicks as well as the main command loop.
6. Add browser/readiness counts to the existing read-only probe and document how to collect its output if Railway still fails.

## Validation

- Core regression cases: Dia and Arc recognition; native apps remain non-browsers; unchanged-title navigation refreshes; expired missing-content cooldown retries the same window; successful reads clear failures; loading and browser windows bypass cooldown.
- Page stability cases: equal-sized observations with changed labels, values or URLs reset stability; missing or loading content never counts as stable; repeated ready observations settle.
- Run native `swift test` and the signed release build in the macOS workflow. Linux can run the platform-independent policy tests in an isolated Swift package using the production source file.
- On the user's Mac, rebuild and ask Dia to open a named Railway project. Switch tabs and repeat without reloading the app. If it still fails, collect the probe's missing-target report before changing target filters.

## Acceptance and limits

The identified retry and navigation conditions have regression coverage, and the macOS tests and release build pass. Live Railway selection remains a manual acceptance check. No accessibility permissions, API credentials, app identity, shortcut, or notch presentation change. No migration or data backfill is required; retry state is in memory.

## Risks

Page observation adds accessibility reads, so traversal and polling remain bounded. Animation can keep a page changing until the timeout. The timeout permits the command loop to continue. An inaccessible or unnamed Railway card may still need a separate naming/filter fix based on actual probe evidence. Existing secure-field exclusions must also apply to page comparisons.

## Code areas

- `Sources/JevCore/BrowserSupport.swift`
- `Sources/JevDesktop/Desktop.swift`
- `Sources/JevDesktop/JevDesktopApp.swift`
- `Tests/JevCoreTests/BrowserSupportTests.swift`
- `README.md`
