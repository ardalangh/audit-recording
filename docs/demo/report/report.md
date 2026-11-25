# Pebblebook Profile Save

demo.mp4 · 780x1688 · 7.6 s · 228 frames · timing resolution about ±33 ms

Saving the profile is the slowest and least clear moment in the flow. After the tap, nothing on screen changes for 1.5 s; then a toast confirms with a different name for the thing just saved. The settings list uses that second name too. The helper text under the form is very faint, and the tab bar is icons only. The demo app is synthetic and its issues were planted to show what the skill reports.

## [P1 · High] F-01 · Save gives no feedback for 1.5 s
- Where: 00:01.000-00:02.533 · Profile · check LAT-FEEDBACK
- Observation: `measure` from the touch at 00:01.000: first visible change +1533 ms (the toast). Nothing in the window changed before that; the button has no pressed or busy state. Timing resolution ±33 ms.
- Expected: Visible feedback within 100 ms of a tap, and a progress state for any wait over about 1 s.
- Impact: The tap looks ignored, so people tap again (double submits) or leave before the save lands.
- Likely cause (inferred): The Save button has no :active or busy style (seen in the code).
- Fix: Darken Save on press, then switch it to a disabled "Saving…" state with a spinner until the request returns.
  - Add an :active style (darker, 98% scale).
  - On submit, disable the button and show "Saving…" with a spinner after 100 ms.
  - Restore it when the request finishes or fails.
  - Save during the request: "No change" -> "Pressed, then "Saving…" with spinner, disabled"
- Verify: Re-record with show-touches on and run `measure`: first change within 100 ms of the tap.

## [P2 · High] F-02 · The same screen is called Profile and Account
- Where: 00:02.533, 00:04.633 · Profile, Settings · check TERM-DRIFT
- Observation: The screen title is "Profile", the save toast reads "Account updated", and the Settings row that opens it is "Account".
- Expected: One name for one thing across title, confirmation and navigation.
- Impact: People can't tell whether they changed their public profile or their account (email, password), and search for the wrong row later.
- Fix: Use "Profile" in all three places and make the toast say what was saved.
  - Toast: "Account updated" -> "Profile saved"
  - Settings row: "Account" -> "Profile"
- Verify: Walk Settings > Profile > Save and read every label: one name.

## [P3 · High] F-03 · Helper text under the form is barely visible
- Where: 00:00.000-00:04.600 · Profile · check CONTRAST-TEXT
- Observation: The line "Your name and bio are shown on notes you share." is ~12 pt light grey on the beige background. From video it looks well below 4.5:1; the code confirms #cfcac3 on #f6f3ee, 1.47:1.
- Expected: Body and helper text at 4.5:1 or more (WCAG 1.4.3).
- Impact: The one sentence that says the bio is public is the hardest to read, so people share details they meant to keep private.
- Fix: Use a darker grey (#6b645c, 5.3:1) for helper text.
  - Helper text colour: "#cfcac3 (1.47:1)" -> "#6b645c (5.27:1)"
- Verify: Check the pair in a contrast checker: 4.5:1 or more.

## [P3 · Medium] F-04 · Tab bar icons have no labels
- Where: 00:04.633-00:07.600 · Settings · check ICON-LABEL
- Observation: The tab bar shows four glyphs with no text. Inactive icons are light grey (#9c958c on white, 2.96:1 per the code).
- Expected: iOS tab bars pair each icon with a short label; icons that are UI components need 3:1.
- Impact: People have to guess what the pencil and magnifier open, and the faint icons are hard to see in sunlight.
- Fix: Add a one-word label under each icon and darken inactive icons.
  - Tabs: "Icons only" -> "Icon + label: Notes, Write, Search, Settings"
  - Inactive colour: "#9c958c" -> "#7a736b"
- Verify: Ask someone new what each tab does before tapping it.

## What works
- Clean, consistent card layout and spacing on both screens.
- The save result is confirmed with a toast rather than silently.

## Evidence limits
- Synthetic recording built from static screens: there is no real motion or transition timing to judge.
- Timing resolution ±33 ms (30 fps).

## Not assessable
- VoiceOver labels and focus order
- Dynamic Type
- Haptics
- Error and offline states (not recorded)

## Signals dismissed
- E03 at 00:04.133 (toast disappearing) is expected behaviour, not a revert.

## Next checks
- Record a failed save (offline) to see the error state.
