# Tether Voice

Voice and typed computer use for macOS. You say what you want. Jev picks the next on-screen action. macOS performs it. No screenshots: the app reads the screen through the Accessibility tree.

A macOS fork of [jev-use](https://github.com/savka777/jev-use) with a voice notch that appears when needed, powered by [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit). Both upstream projects are MIT licensed.

## Quick start

Requires macOS 14.2+ and Xcode 16 or newer with a Swift 6 toolchain.
Swift Package Manager fetches DynamicNotchKit 1.1.0 during the first build.

```sh
mkdir -p "$HOME/Code"
cd "$HOME/Code"
git clone https://github.com/TetherAI-ca/tether-voice-macos.git
cd tether-voice-macos
bash build.sh
open "$HOME/Applications/Tether Voice.app"
```

If you used Desktop Voice before, quit it first so the speech shortcut is free. Tether Voice installs as a separate app with its own settings and Keychain entry. Enter your key and grant permissions again on the first launch.

In setup: save your TypeSafe API key (stored in the Keychain), then allow Accessibility, microphone and speech.

Hold **Control–Option–Space**, speak, release. **Escape** cancels an active command
or hides an idle notch. Type a command in **Settings and commands**, or from a
shell: `scripts/say.sh "Open Finder"`.

## Voice notch

The voice interface stays completely hidden while idle, with no logo or shortcut
icons beside the camera notch. Hold Control–Option–Space to show it at the top
center of your primary display. It stays open during speech and command execution.
Results remain visible for four seconds, then the notch disappears. Hovering over
an open result keeps it readable; hovering at the top of the screen when hidden
does not open it. Clarification questions stay visible until answered or dismissed.

The default recording view is a small line of live text. Longer commands keep the
newest spoken words visible; the full text is available on hover. After release,
the same view shows command progress and results. Errors and clarification
questions can wrap to three lines. There are no pixels, logo, app title, buttons,
or shortcut hints inside the notch.

Use **Escape** to cancel, or use the menu-bar icon for **Show voice notch**,
**Hide voice notch**, **Settings and commands**, and **Cancel current command**.
Hiding it while busy also cancels pending work. The audio visualizer and its
system-audio capture have been removed; microphone capture still powers speech.

On displays without a physical notch, it uses the same top-edge notch presentation.
The panel does not move keyboard focus to Tether Voice when it opens. Closing Settings
leaves the notch hidden unless a command or clarification is pending. Typed commands
and the explicit **Show voice notch** menu action also open it. Presentation
animations respect macOS Reduce Motion.

This replaces the draggable floating widget. Its saved position is no longer used.

### Verify on your Mac

Quit Tether Voice before running `swift test` and `bash build.sh`. Then reopen it
with `open "$HOME/Applications/Tether Voice.app"` and check:

- Launch and closing Settings leave no logo, shortcut icons, or panel at the notch.
- Hovering over the camera notch while idle does not open the voice interface.
- Holding the speech shortcut expands it without taking focus from the target app.
- Recording shows only one small line of live text, with the latest words visible in a long sentence.
- Releasing the shortcut keeps the transcript visible until final recognition arrives, then shows command status in the same view.
- A command stays expanded if you move the pointer away; its result stays readable for four seconds, then disappears.
- Hovering over a result keeps it visible; moving away hides it after the remaining result time or 0.6 seconds, whichever is longer.
- Pressing the shortcut while the notch is hiding reopens it for the new command.
- Escape and the menu-bar Cancel action stop pending work; clarification questions stay visible and can wrap to three lines.
- Settings and its close/Done controls return to the notch, with keys and permissions intact.
- The menu-bar Show and Hide commands work, including while speaking.
- Check a notched display, an external display, full-screen apps, and Reduce Motion.

## Examples

- "Open Obsidian, create a new note and type hello"
- "Go to youtube.com, search Rick Astley and play the first video"
- "Open 3 new tabs"
- "Scroll down three times"
- "Tile all the Brave windows so none are stacked"
- "In every Brave window, go to wikipedia.org and search for accessibility" — Jev works out the steps once, code repeats them in each window
- "Close the window", "Save", "New tab" — any item in the app's menu bar

## How it works

One loop, about 0.3–1.5 s per step:

1. **Read.** Walk the front app's Accessibility tree (~120 ms). Every element describes itself: what it is, its name, its value, where it sits, what it can do. No per-app code.
2. **Choose.** One request to Jev (`jev-latest`): the goal, the numbered targets, the last ten actions and their effects. Jev selects an operation and a target. It never generates free text; typed text is a span of your sentence.
3. **Act.** Press, select, type, menu, key, scroll, open, arrange windows.
4. **Check.** Read the screen again. Report the real effect. Repeat until DONE, BLOCKED or WAIT.

Low-confidence and destructive picks stop and ask instead of acting.

## What is sent

To `https://api.typesafe.ai/v1/systemone`: your command, the app and window names, the on-screen targets with their labels and values, and recent actions. Secure text fields are excluded. No screenshots. Speech uses Apple Speech.

Everything is logged locally: `log show --predicate 'subsystem == "ai.tether.voice"' --last 10m --info`

## Browser troubleshooting

Dia and Arc are recognized as Chromium browsers, alongside Chrome, Brave and Edge.
Tether Voice requests their page accessibility tree and retries if it disappears.
Clicks, tab switches and navigation refresh the page even when the window title
stays the same. Page settling compares labels, values and URLs as well as structure.
Navigation may wait briefly for the new controls to appear.

After updating, try selecting a named Railway project in Dia, then switch tabs and
repeat. If a visible card is still missing, the existing read-only probe can compare
the browser's accessible controls with the targets Tether Voice offers to Jev:

1. Quit Tether Voice, run `defaults write ai.tether.voice DebugHooks -bool true`,
   then reopen the app.
2. In this repository, run `sleep 5; scripts/say.sh "/probe"` and bring Dia's
   Railway tab to the front during the five-second delay. Keep the page still
   while the probe runs. It does not click, type, or call Jev.
3. Read the result with:

   ```sh
   log show --predicate 'subsystem == "ai.tether.voice" AND eventMessage CONTAINS "Probe"' --last 5m --info
   ```

The summary reports browser recognition, Chromium detection, page readiness and
the number of offered page targets. `pageReady=false` points to missing or loading
web content. `Probe missed` lists accessible controls that did not become offered
targets. These logs can contain page titles and control labels; remove private
content before sharing. A card that the browser never exposes may not appear in
either list.

Disable diagnostic commands afterward with
`defaults write ai.tether.voice DebugHooks -bool false` and restart Tether Voice.

## Develop

```sh
swift test        # existing core tests
bash build.sh     # quit the app first
```

GitHub Actions runs the existing tests and release build on macOS. Check the workflow result for your commit before installing. Hover behavior, permissions, and display changes still need the manual checks above.

## Credits

Built on [savka777/jev-use](https://github.com/savka777/jev-use). The original MIT license and Git history are preserved. Notch presentation uses [MrKai77/DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit), pinned to 1.1.0.
