# Voice notch implementation

## Goal and agreed behavior

Replace the draggable voice widget with a DynamicNotchKit presentation. The user
now wants the notch completely hidden at idle, including the logo and shortcut
icons. It appears when they press Control–Option–Space. This replaces the earlier
compact-at-idle and hover-to-open preference. Keep the
current command execution, TypeSafe integration, and speech shortcut. Publish the
customized fork as Tether Voice.

## Source and compatibility

- DynamicNotchKit is pinned to `1.1.0`, commit
  `cd0b3e52d537db115ad3a9d89601f20e0bee8d27`.
- Local reference: `~/Code/reference/dynamicnotchkit`. Read its `DynamicNotch.swift`,
  hover behavior, transition configuration, and notch views before changing calls.
- It requires a Swift 6 toolchain. Tether Voice retains its macOS 14.2 deployment target
  and existing Swift language mode; build with Xcode 16 or newer.
- Use the expanded-only DynamicNotch initializer with empty compact content.
  Keep `.notch` style for a top-edge presentation on every display. Never request
  compact mode.
- Observe the public `isHovering` publisher only to keep an already visible result
  readable. Hovering must not reveal a hidden notch.
- The library's `state` property is internal. Track completed presentation requests
  in the controller instead of reaching into that property.

## Implementation phases

1. Add and catalog the pinned reference. Add the exact Swift package dependency to
   `Package.swift`, linked only by `JevDesktop`.
2. Add `VoiceNotchController` in `Sources/JevDesktop/VoiceNotch.swift`. It owns one
   retained DynamicNotch instance, hover observation, dismissal timing, and serialized
   hidden/expanded requests. Recompute the requested destination after each awaited
   transition so pending dismissal work cannot hide a newly started command.
3. Connect AppModel's presentation methods and busy transitions to the controller.
   Do not show a notch while loading the key or after setup. Expand on speech/commands,
   show results for four seconds, then hide. Hold clarification questions open.
   Hover exit hides after the remaining result time or 0.6 seconds, whichever is
   longer. Settings hides the notch; closing it restores only a pending command or
   clarification, otherwise the notch stays hidden.
4. Present expanded content with speech pixels, transcript, status, settings,
   cancellation, and a Hide control. Remove the compact logo and shortcut controls. Move the existing pixel
   drawing code to `VoicePixelField.swift` without changing its rendering algorithm.
5. Retain the existing menu-bar access, with explicit Show and Hide actions. Escape
   cancels busy work and hides an idle notch. Hide cancels busy work and removes
   the notch; the next command or Show action restores it.
6. Document the toolchain and run the Mac validation checklist in `README.md`.

## Lifecycle and accessibility

The primary display owns the notch, matching DynamicNotchKit's display-change
handling. Opening it uses a nonactivating panel. Serialize `expand` and `hide`
because they animate asynchronously. Do not enable the dependency's
`keepVisible` behavior: an explicit Settings/Hide action must work while hovered.
Stop the system-audio visualizer when hidden. Release timers and close
the panel on shutdown. Honor Reduce Motion in the pixel view and configured
presentation animations. Give icon controls accessibility labels.

## Acceptance criteria

- Launch, key loading, and closing Settings while idle show no notch or side icons.
- Hovering while hidden does not reveal any controls.
- The speech shortcut opens the notch on the primary display. Typed commands and
  the explicit Show menu action remain available.
- Speaking and active commands remain expanded even when the pointer leaves.
- Completion stays readable for four seconds before the notch disappears. Clarification stays open until answered
  or explicitly dismissed; reopening must not clear its question.
- Settings, cancellation, explicit Hide/Show, and rapid transitions work together.
- Speech, typed commands, keys, permissions, and the target app's keyboard focus
  continue to work.
- Build and existing tests pass on macOS. Verify external displays, full-screen apps,
  Reduce Motion, and rapid hover/command changes on real hardware.

## Rollout and verification limits

Tether Voice uses a separate `ai.tether.voice` bundle identifier, Keychain service,
command notification, logging subsystem, and local signing identity. It installs as
`~/Applications/Tether Voice.app`; the upstream Desktop Voice app can remain installed
but must be quit to free the shared shortcut. Users re-enter their API key and grant
permissions on first launch. No existing credentials are copied.
The old widget-position preference is unused. Build and locally sign through
`bash build.sh`, quitting the installed app first.

The implementation workspace is Linux without Swift or the macOS SDK. Source and
syntax checks here cannot establish successful compilation or native UI behavior.
GitHub Actions runs dependency resolution, `swift test`, and `bash build.sh` on
macOS. The manual checklist still requires the user's Mac before treating the UI
behavior as verified.

Checks completed in the implementation workspace:

- Tree-sitter Swift syntax parsing passed for the manifest, app entry point, and
  new notch and pixel renderer files. This is syntax validation, not Swift type checking.
- The extracted pixel renderer matches the original implementation apart from its
  imports and file-level access modifier.
- The package's exact dependency version matches the reference checkout's tag.
- `git diff --check` passed.
- The initial notch implementation at `1780fbd` passed macOS tests, release build,
  and app signing in GitHub Actions. Run the same workflow for this idle-visibility
  update; hardware behavior still needs the manual checklist.

The repository includes a macOS GitHub Actions workflow for tests and a release build.
Hardware behavior still requires the manual checklist.

Rollback can use the original Desktop Voice installation and its original credentials
and permissions. Quit Tether Voice first so the shortcut is available.
