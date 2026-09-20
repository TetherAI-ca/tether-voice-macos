# Replace the voice widget with a compact notch

## Summary

Move Tether Voice's inherited voice UI to DynamicNotchKit 1.1.0. Keep it compact at idle and expand
on hover or speech, as requested by the user.

## Current state and resulting behavior

The original app used a draggable 244 × 172 floating panel. The working branch adds
a notch on the primary display with compact controls, expanded speech/status content,
settings access, cancellation, result timing, and clarification handling.

## Functional requirements

- Expand throughout speech and command execution; preserve the existing control loop.
- Display results before collapsing and keep unanswered clarification visible.
- Preserve settings, typed commands, menu-bar access, and Escape cancellation.
- Offer explicit Show/Hide and collapse controls with accessible labels.
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
install, then check hover/voice transitions, focus, results, cancellation, settings,
display changes, full-screen apps, and Reduce Motion. Linux syntax checks do not
replace an AppKit/SwiftUI build. GitHub Actions runs tests and a release build on
macOS. Users enter their API key and grant permissions once for the new Tether Voice
app. Quit Desktop Voice first to free the speech shortcut. Existing upstream
credentials and settings remain in place.

## Risks and watchouts

The library manages an asynchronous panel lifecycle and recreates panels when displays
change. Verify rapid show/hide and screen changes on hardware. Its floating style
cannot remain compact, so this integration explicitly uses notch style. Its internal
state is not a public API. Avoid coupling the controller to internal library members.

This is a local engineering handoff, not a published issue or deployment.
