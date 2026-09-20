# Recover Dia page controls after navigation

## Summary

Fix browser classification and accessibility refresh behavior when Tether Voice controls Dia, including same-title navigation on sites such as Railway.

## Why

The user can reach a browser tab but cannot reliably select a Railway project. The screenshot confirms visible project cards, but does not tell us which accessibility elements Dia exposes.

## Current state

Dia is absent from the browser list. A window that times out without web content can be skipped indefinitely. Several refresh paths require a changed window title. Page settling compares only element counts.

## Goal

Give the model a fresh set of page controls after browser actions, and recover when a browser temporarily exposes only its toolbar.

## Functional requirements

- Recognize Dia and Arc and retain current-browser URL behavior.
- Retry missing browser content and expire non-browser missing-content cooldowns.
- Refresh after page-affecting actions even when the title is unchanged.
- Observe content and loading state when waiting for a page to settle.
- Keep a read-only diagnostic that separates missing browser content from missing offered targets.

## Technical requirements

Share browser and retry decisions through tested core code. Preserve Chromium framework discovery for Electron. Serialize retry-cache mutations. Bound tree traversal and wait durations, and preserve cancellation and secure-field exclusions. Do not broaden click targeting without evidence from an actual accessibility trace.

## UX guidance

Keep the current hidden-idle notch, minimal recording text, shortcut, and Settings behavior. Page recovery can use the existing waiting status.

## Rollout expectations

Run core regressions and the macOS release build before directing the user to rebuild. Publish to the existing public `TetherAI-ca/tether-voice-macos` repository. No credential, permission, or stored-data migration is needed.

## Acceptance criteria

- Regression tests cover browser identity, same-title navigation, cooldown expiry, successful recovery, and content stability.
- macOS tests and signed release build pass.
- The user can select a named Railway project in Dia and repeat after switching tabs. This last check requires the user's Mac and account.

## Risks / watchouts

Railway may still expose unnamed or filtered controls. Use the diagnostic output to distinguish that case from a missing page tree. Avoid claiming end-to-end success based on policy tests alone.

## Relevant code areas

`BrowserSupport.swift`, `Desktop.swift`, `JevDesktopApp.swift`, `BrowserSupportTests.swift`, and the README troubleshooting instructions.

## Notes for handoff

The full implementation plan is in `docs/browser-accessibility-implementation.md`. Do not change the unrelated private `TetherAI-ca/tether-voice` project.
