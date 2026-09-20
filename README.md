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

The expanded view contains the speech pixels, transcript, status, Settings button,
and a Cancel button while a command is running. The up-chevron hides it when
idle. The menu-bar icon offers **Show voice notch**, **Hide voice notch**, settings,
and cancellation. Hiding it while busy also cancels pending work.

On displays without a physical notch, it uses the same top-edge notch presentation.
The panel does not move keyboard focus to Tether Voice when it opens. Closing Settings
leaves the notch hidden unless a command or clarification is pending. Typed commands
and the explicit **Show voice notch** menu action also open it. The visualizer runs only while visible;
the speech pixels and presentation transitions respect macOS Reduce Motion.

This replaces the draggable floating widget. Its saved position is no longer used.

### Verify on your Mac

Quit Tether Voice before running `swift test` and `bash build.sh`. Then reopen it
with `open "$HOME/Applications/Tether Voice.app"` and check:

- Launch and closing Settings leave no logo, shortcut icons, or panel at the notch.
- Hovering over the camera notch while idle does not open the voice interface.
- Holding the speech shortcut expands it without taking focus from the target app.
- A command stays expanded if you move the pointer away; its result stays readable for four seconds, then disappears.
- Hovering over a result keeps it visible; moving away hides it after the remaining result time or 0.6 seconds, whichever is longer.
- Pressing the shortcut while the notch is hiding reopens it for the new command.
- Escape and Cancel stop pending work; clarification questions stay visible.
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

## Develop

```sh
swift test        # existing core tests
bash build.sh     # quit the app first
```

GitHub Actions runs the existing tests and release build on macOS. Check the workflow result for your commit before installing. Hover behavior, permissions, and display changes still need the manual checks above.

## Credits

Built on [savka777/jev-use](https://github.com/savka777/jev-use). The original MIT license and Git history are preserved. Notch presentation uses [MrKai77/DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit), pinned to 1.1.0.
