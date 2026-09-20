# Show the voice notch only when needed

## Summary

Use DynamicNotchKit 1.1.0 for Tether Voice's command UI. Following the user's latest
feedback, hide the notch and both side icons while idle. Open it on the speech
shortcut, a typed command, or an explicit Show action.

## Current state and resulting behavior

The original app used a draggable 244 × 172 floating panel. The working branch adds
a notch on the primary display with expanded speech/status content, settings access,
cancellation, result timing, and clarification handling. The earlier compact logo
and shortcut controls are removed; hover no longer opens the hidden interface.

## Functional requirements

- Expand throughout speech and command execution; preserve the existing control loop.
- Keep results visible for four seconds, then hide; keep unanswered clarification visible.
- Start hidden, including while loading saved keys; stay hidden after idle Settings closes.
- Keep hovered results visible without allowing hover to reveal a hidden notch.
- Preserve settings, typed commands, menu-bar access, and Escape cancellation.
- Offer explicit Show/Hide and dismissal controls with accessible labels.
- Use a top-edge notch on displays without a physical notch.

## Technical requirements

Pin DynamicNotchKit exactly to 1.1.0. Require a Swift 6 toolchain. Keep the current
macOS deployment target. Use `ai.tether.voice` as the fork's separate app identity
and store its keys independently. Serialize asynchronous
presentation transitions and stop the music visualizer when it is not displayed.

## Relevant code

- `Package.swift`: package dependency.
- `Sources/JevDesktop/VoiceNotch.swift`: controller and notch content.
- `Sources/JevDesktop/VoicePixelField.swift`: existing pixel renderer, moved out of AppModel.
- `Sources/JevDesktop/JevDesktopApp.swift`: presentation and lifecycle integration.
- `README.md`: user behavior and Mac verification checklist.
- `docs/notch-implementation.md`: full implementation decisions and acceptance criteria.

## Validation and rollout

Mac validation is still required: resolve dependencies, run existing tests, build and
install, then check hidden idle state, shortcut/voice transitions, focus, results, cancellation, settings,
display changes, full-screen apps, and Reduce Motion. Linux syntax checks do not
replace an AppKit/SwiftUI build. GitHub Actions runs tests and a release build on
macOS. Users enter their API key and grant permissions once for the new Tether Voice
app. Quit Desktop Voice first to free the speech shortcut. Existing upstream
credentials and settings remain in place.

## Risks and watchouts

The library manages an asynchronous panel lifecycle and recreates panels when displays
change. Verify rapid show/hide and screen changes on hardware. Use the expanded-only
initializer, request only hidden or expanded states, and retain notch style on all
displays. The library's internal state is not a public API. Avoid coupling the
controller to internal library members.

This is a local engineering handoff, not a published issue or deployment.
