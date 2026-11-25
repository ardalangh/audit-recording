# Platform UI / Design / Latency Reference (for screen-recording audits)

Researched 2026-11-24 from the live pages listed under Sources. All rules are paraphrased. Tags in brackets name the source (key at the bottom). `[practice]` marks widely followed convention that no fetched source states directly. Treat those as lower-severity findings.

Severity hint for the auditor: **P1** breaks a hard threshold (WCAG AA, vitals "poor", frozen frame). **P2** is a "needs work" band or a platform-convention violation. **P3** is polish.

---

## 1. Latency & responsiveness thresholds

### 1a. Cross-platform thresholds

| Interaction / metric | Good | Needs work | Poor | Source |
|---|---|---|---|---|
| Discrete input (tap, click, key) to first visible response | ≤100 ms (feels instant) | 100–250 ms (noticeable) | >250 ms (Apple tools flag a "hang") / >1 s (flow broken) | [NN-RT] [RAIL] [AP-HANG] |
| Web interaction latency (INP, p75) | ≤200 ms | 200–500 ms | >500 ms | [CWV-INP] |
| Direct manipulation (drag, scroll, pinch) | Content tracks the finger or cursor every frame | Lag of 1–2 frames is visible | Content detaches from the pointer or stalls | [NN-RT] [RAIL] |
| Animation frame budget | 60 Hz: 16.7 ms. 90 Hz: 11 ms. 120 Hz: 8.3 ms | Occasional missed frames | Sustained misses | [AND-JANK] [AP-HITCH] |
| Apple hitch rate | ≤10 ms/s | 10–25 ms/s (warning) | 25–50 ms/s critical; >50 ms/s needs immediate attention | [AP-HITCH] |
| Android frame class | <16 ms | Slow frame: 16–700 ms | Frozen frame: 700 ms–5 s. ANR: >5 s with no input response | [AND-JANK] |
| Web page main content visible (LCP, p75) | ≤2.5 s | 2.5–4.0 s | >4.0 s | [CWV-LCP] |
| Web layout stability (CLS, p75) | ≤0.1 | 0.1–0.25 | >0.25 | [CWV-CLS] |
| Web load to interactive (RAIL) | Repeat load ≤2 s | First load ≤5 s on mid-range mobile, slow 3G | >5 s | [RAIL] |
| Android cold start (time to first frame, TTID) | well under 5 s | — | ≥5 s is "excessive" | [AND-LAUNCH] |
| Android warm / hot start | <2 s / <1.5 s | — | ≥2 s / ≥1.5 s is excessive | [AND-LAUNCH] |
| iOS launch | First frame "instantly"; people won't wait more than "a couple of seconds" | — | Watchdog kills a launch that takes too long | [AP-LAUNCH] [AP-LAUNCHDOC] |
| Attention limit for any wait | <1 s keeps flow | 1–10 s needs a busy indicator | >10 s needs percent-done, a time estimate and Cancel | [NN-RT] [NN-PROG] |

### 1b. Loading-indicator rules

| Expected wait | Correct feedback | Wrong | Source |
|---|---|---|---|
| <1 s | None beyond the result. A spinner that flashes for a frame or two counts as a defect | Spinner or skeleton that flickers briefly | [NN-PROG] [NN-SKEL] |
| ~1–2 s | Some busy signal: pressed state, busy cursor, or inline indicator | Nothing changes, so the user taps again | [NN-RT] [NN-PROG] |
| 2–10 s | Looping spinner (for a single module) or skeleton (for a full page), ideally with specific text such as "Loading comments…" | Static "Loading…" text. A frame-only skeleton showing just header and footer | [NN-PROG] [NN-SKEL] [AP-PROG] |
| >10 s | Determinate progress bar, time estimate, Cancel option | Indeterminate spinner beyond 10 s | [NN-PROG] [NN-SKEL] |
| Any | Keep the indicator moving. A frozen spinner reads as a crashed app | Stalled bar | [AP-PROG] |
| Any | Switch indeterminate to determinate once the total is known. Never morph a spinner into a bar | Spinner changing into a bar | [AP-PROG] |
| Any | Progress advances at an even pace (no 90 % in 5 s, then a long stall) | Jumpy or backward progress | [AP-PROG] |
| macOS | Spinner for background work, without a label | — | [AP-PROG] |
| iOS launch | Launch screen nearly identical to the first screen, with no text and no branding | Splash or ad, then a visible flash on swap | [AP-LAUNCH] |

### 1c. What can be measured from a 30/60 fps recording

| Measurement | How to read it from frames | Resolution and caveats |
|---|---|---|
| Frame period | 30 fps = 33.3 ms per frame. 60 fps = 16.7 ms per frame | Any latency is ±1 frame. A 30 fps capture cannot judge 60 Hz smoothness, only stalls of 2 or more frames (≥67 ms) |
| Input moment (t0) | Android "Show taps" dot, iOS AssistiveTouch or touch-indicator overlay, cursor-click halo, key-press overlay, or the first frame of a pressed state | Without a visible input marker, report latency as "from first visible press state" |
| Input to first visual response | Frames from t0 to the first changed pixel in the target region (highlight, ripple, cursor change) | Compare with 100 ms (6 frames at 60 fps, 3 at 30 fps) and 250 ms (15 / 7.5 frames) |
| Time to settled | t0 to the last frame where the region changes (content loaded, animation finished, no further shifts) | Compare with 1 s / 10 s and the LCP-like 2.5 s |
| Spinner / skeleton duration | First to last frame the indicator is visible | <1 s with a spinner flags flicker. >10 s with an indeterminate indicator flags missing progress |
| Stutter / hitch | Runs of identical consecutive frames (a frame-diff of ~0) during motion that should be continuous: scroll, transition, drag | At 60 fps capture, 1 repeated frame ≈ 1 missed vsync. ≥42 identical frames (~700 ms) ≈ Android "frozen frame". Rule out recorder drops: if the clock or cursor keeps moving while content is static, the app hitched |
| Hitch ratio estimate | Sum of the extra time from repeated frames ÷ animation duration (ms/s) | Compare with Apple's 10 / 25 / 50 ms/s bands |
| Layout shift | Visible content jumps position without the user causing it, especially more than 500 ms after the last input | CLS can't be computed exactly. Estimate as shifted area fraction × distance fraction of the viewport. Flag any jump of a text block or button the user was about to hit |
| Animation duration | Frames from motion start to motion end | Compare with M3 tokens (50–1000 ms; most UI 200–500 ms) or Windows (83 / 167 / 250 / 333 ms). >500 ms for frequent UI is sluggish |
| Flashing | Count luminance flips per second | >3 flashes in any 1 s fails WCAG 2.3.1 |
| White flash on open | Blank white or black frame(s) before the first content frame (window open, route change, dark-mode app) | Electron: suggests missing `backgroundColor` or `ready-to-show`. iOS: launch screen doesn't match the first screen |

---

## 2. Mobile checklist (iOS + Android)

### Touch targets & spacing
- Tappable controls have a hit area of at least **44×44 pt** on iOS (28×28 pt absolute minimum) [AP-ACC] [AP-BTN], and at least **48×48 dp** on Android [AND-A11Y]. A visually smaller icon is acceptable if the hit area is padded out to that size.
- Padding between controls is about **12 pt** around bezeled elements and about **24 pt** around borderless ones (iOS) [AP-ACC]. Material components sit on a 4 dp / 8 dp spacing increment [M3-sec].
- Spacing between like elements is consistent, and alignment is shared [AND-LAYOUT].
- Primary navigation and the main action sit within thumb reach at the bottom. The FAB is 56 dp (96 dp large) [AND-LAYOUT] [MDC-FAB].

### Safe areas & system UI
- No content or controls under the status bar, Dynamic Island or notch, home indicator, display cutouts, or gesture-nav area. Content honors safe-area insets [AP-LAYOUT] [AND-LAYOUT].
- Android 15+ draws edge-to-edge by default. Check that the app bar and bottom content aren't hidden behind system bars, and that scrolling content can pass under translucent bars [AND-LAYOUT] [practice].
- When the keyboard opens, the focused field stays visible (it moves up or attaches to the keyboard). An input is never hidden behind the keyboard [AND-LAYOUT].
- Layout adapts across rotation and size classes without losing function. iOS uses compact/regular size classes [AP-LAYOUT]. Android width classes are **<600 / 600–840 / 840–1200 / 1200–1600 / ≥1600 dp** [AND-WSC]. Phones in landscape are usually compact height (<480 dp), where two-pane layouts don't fit [AND-WSC].
- Material margins are **16 dp** in compact width and **24 dp** in medium and expanded, with a 24 dp spacer between panes [M3-sec].

### Typography
- iOS body text defaults to **17 pt** (minimum 11 pt). On the iOS Large (default) Dynamic Type scale, the large title is 34 pt and caption 2 is 11 pt [AP-TYPE] [AP-ACC].
- Android uses the M3 type scale in **sp**: Display 57/45/36, Headline 32/28/24, Title 22/16/14, Body 16/14/12, Label 14/12/11 [MDC-TYPE]. Text set in dp, or text that doesn't scale with system font size, is a defect [AND-A11Y].
- At the largest text size, layouts reflow: no clipped or overlapping text, minimal truncation, and icons grow with the text [AP-TYPE].
- Apps should support enlarging text to at least **200 %** [AP-ACC].

### Color & contrast
- Text contrast is at least **4.5:1**. Large text (iOS ≥18 pt or bold; Android ≥18 sp, or ≥14 sp bold) needs **3:1** [AP-ACC] [AND-A11Y] [WCAG].
- UI component boundaries and meaningful icons need **3:1** against adjacent colors [WCAG 1.4.11].
- Check contrast in both light and dark mode [AP-ACC].
- Tab and toolbar label colors should stand out from colorful content beneath them [AP-TAB] [AP-TOOLBAR].

### Navigation
- **iOS tab bar:** used for navigation, not actions. It stays visible across sections and hides only under a modal. Each tab has an icon and a short label, usually one word. Don't hide or disable tabs. Avoid an overflow "More" tab. A red badge signals critical information only. In current iOS the bar floats over content and can minimize on scroll [AP-TAB].
- **iOS nav / toolbar:** uses the standard Back button. The large title collapses to an inline title on scroll. The title should be under 15 characters, and should not be the app name. Use no more than 3 toolbar groups. Don't place a text-labeled action next to a symbol action [AP-TOOLBAR].
- **iOS sheets:** Cancel on the leading edge, Done on the trailing edge. Never show Cancel, Done and Back together. A resizable sheet shows a grabber. Swipe-down dismisses, and asks for confirmation if there are unsaved changes. Only one sheet is open at a time [AP-SHEET].
- **Android navigation bar:** **64 dp** tall in M3 Expressive (80 dp in the earlier M3 baseline) for 3–5 destinations. Use a navigation rail (**80–96 dp** wide) at medium and expanded widths [MDC-NAV] [MDC-RAIL].
- **Android:** system Back and predictive-back gestures work, with no dead-end screens [practice]. Bottom sheets have a drag handle with a **48 dp** minimum target [MDC-SHEET].
- **Platform mix-ups (P2):** iOS-style chevron back or tab bar on Android, or Material FAB and ripple on iOS, without good reason [AP-*] [practice].

### Motion & feedback
- Every tap gives instant visual feedback: highlight on iOS, ripple or state layer on Android, within 100 ms [NN-RT] [RAIL].
- Material motion duration tokens are 50, 100, 150, 200 (short), 250–400 (medium), 450–600 (long) and 700–1000 ms (extra long). Duration should grow with the distance or area an element travels [MDC-MOTION].
- Animations can be interrupted. Users shouldn't have to wait out an animation, and frequent interactions get little or no custom motion [AP-MOTION].
- Motion respects Reduce Motion and Remove Animations settings. Motion is never the only signal [AP-MOTION] [WCAG 2.3.3].
- No scroll hitching in lists. Frozen frames (>700 ms) should not appear even during screen transitions [AND-JANK].
- Pull-to-refresh shows a refresh control, and content also refreshes automatically [AP-PROG].

### Launch
- **iOS:** the launch screen matches the first screen (no logo splash, no text) and gives way to it with no flash. The app launches in the device's current orientation and restores its previous state [AP-LAUNCH].
- **Android:** the system SplashScreen API runs on Android 12+, with no second custom splash activity. Cold-start TTID should stay under 5 s, warm under 2 s and hot under 1.5 s [AND-LAUNCH].

---

## 3. Web checklist (responsive, desktop and mobile web)

### Performance (from recording)
- Main content is visible within **2.5 s** of navigation (poor if >4 s) [CWV-LCP].
- Every click or tap updates the UI within **200 ms** (poor if >500 ms). Visible feedback within 100 ms is the goal [CWV-INP] [RAIL].
- No unexpected layout shifts: late images or ads pushing text, or font swaps reflowing the page. Shifts within 500 ms of a user action are acceptable. Target CLS ≤0.1 [CWV-CLS].
- Scrolling and animations run at a steady frame rate (≈16 ms frames at 60 Hz) [RAIL].
- Full-page loads show a skeleton that resembles the final layout. A single widget uses a local spinner. Uploads and downloads use a determinate bar [NN-SKEL].
- No full-screen blocking spinner for partial updates [NN-SKEL] [practice].

### Responsive layout
- At **320 CSS px** width, content reflows to a single column with no horizontal scrolling (except data tables, maps and similar 2-D content) [WCAG 1.4.10].
- Text zoomed to 200 % loses no content or function [WCAG 1.4.4].
- Text with spacing overrides (line height 1.5×, paragraph spacing 2×, letter spacing 0.12×, word spacing 0.16×) doesn't clip or overlap [WCAG 1.4.12].
- Body text is about 16 px on mobile [practice]. Inputs use ≥16 px text so iOS Safari doesn't zoom on focus [practice].
- Line length for reading text is about 50–75 characters. Windows guidance says 50–60 [WIN-TYPE] [practice].
- Mobile web respects safe-area insets (`env(safe-area-inset-*)`) for notched devices in landscape. Fixed bars don't cover content [AP-LAYOUT] [practice].
- On touch layouts, primary targets meet the platform touch sizes: 44 pt on iOS, 48 dp on Android [AP-ACC] [AND-A11Y].

### Targets, focus, keyboard
- Pointer targets are at least **24×24 CSS px**, or have a 24 px-diameter spacing circle that doesn't touch other targets (AA). The AAA level is **44×44** [WCAG 2.5.8 / 2.5.5].
- Keyboard focus is always visible. Watch for `outline: none` with no replacement [WCAG 2.4.7].
- Sticky headers, cookie banners and chat widgets must not fully cover the focused element [WCAG 2.4.11].
- Good focus indicator: at least a 2 px perimeter with 3:1 contrast between focused and unfocused states (AAA) [WCAG 2.4.13].
- Content shown on hover or focus (tooltips, menus) can be dismissed with Esc, can itself be hovered, and stays visible until dismissed [WCAG 1.4.13].
- Every drag action has a single-pointer alternative, such as buttons or a menu [WCAG 2.5.7].

### Color, motion, media
- Text contrast is **4.5:1**, or **3:1** for large text (≥24 px regular, or ≥18.66 px bold). UI components and graphics need **3:1** [WCAG 1.4.3 / 1.4.11]. AAA text contrast is 7:1 [WCAG 1.4.6].
- Auto-playing motion, carousels or tickers that run longer than **5 s** need a pause, stop or hide control [WCAG 2.2.2].
- No more than **3 flashes per second** [WCAG 2.3.1].
- Animations triggered by interaction honor `prefers-reduced-motion` [WCAG 2.3.3].

### Heuristics (any platform, visible in recordings) [NN-H10]
1. System status is visible: every action gets prompt feedback.
2. Wording and icons match real-world language, with no internal jargon.
3. User control: Undo, Cancel and Back are available, and every modal has a way out.
4. Consistency: the same component looks and behaves the same everywhere, and follows platform conventions.
5. Error prevention: destructive actions are confirmed, constraints are clear, and defaults are sensible.
6. Recognition over recall: options are visible, not memorized.
7. Flexibility: shortcuts are available for experienced users.
8. Minimalist design: no clutter competing with the primary task.
9. Errors are in plain language, state the cause and suggest a fix, near the field.
10. Help is in context, short and task-focused.

---

## 4. Desktop checklist (macOS, Windows, Electron)

### Shared desktop rules
- Controls are pointer-sized. macOS default is **28×28 pt** (minimum 20×20 pt) [AP-ACC]. Windows touch-capable targets are about **7.5 mm ≈ 40×40 epx** [WIN-TARGET].
- Hover states exist for interactive elements. The pointer shows an arrow by default and an I-beam over editable text [AP-POINTER] [practice].
- The window resizes fluidly. Content reflows at minimum size, and toolbar items overflow into the system "»" menu, not off-screen [AP-WIN] [AP-TOOLBAR].
- Window chrome distinguishes active and inactive (key / main) windows [AP-WIN] [WIN-TITLE].
- A busy state over 1 s shows a busy cursor or inline progress. On macOS, no spinning wait cursor should ever appear: that means the main thread hung for over 250 ms [NN-RT] [AP-HANG].

### macOS
- **Menu bar:** standard menus appear in the standard order: App, File, Edit, Format, View, (app-specific), Window, Help. The App menu has About first (alone in its group), then Settings…, Services, Hide, Hide Others, Show All, and Quit. Menu titles are one word. Unavailable items are dimmed, not hidden [AP-MENU].
- Standard shortcuts work: ⌘C/V/X/Z, ⌘S, ⌘W, ⌘Q, ⌘, (Settings), ⌘N, ⌘O [AP-MENU].
- **Toolbar:** sits in or under the title bar. Every toolbar command also exists in the menu bar. No more than 3 groups. The window title is useful (not the app name) and under 15 characters. Traffic-light window controls must not overlap toolbar items [AP-TOOLBAR] [AP-WIN].
- Avoid custom window frames or controls, and never fake the traffic lights [AP-WIN].
- **Sheets:** a card attached to the parent window, which dims. Sized sensibly by default. Other app windows stay usable [AP-SHEET].
- **Text:** system body text is **13 pt** (minimum 10 pt). macOS has no Dynamic Type [AP-ACC] [AP-TYPE].
- An app icon bouncing in the Dock is the launch indicator. The first window should appear quickly, with state restored [AP-LAUNCHDOC] [AP-LAUNCH].

### Windows (Fluent / Windows 11)
- **Title bar:** **32 px** standard, **48 px** when it hosts search or a person picture. The icon is 16×16 px, placed 16 px from the edge and vertically centered. The title uses Caption style, 16 px from the icon. Empty space is draggable. Double-click toggles maximize. Right-click opens the system menu. Title elements turn semi-transparent when the window is inactive [WIN-TITLE].
- **Caption buttons:** minimize, maximize/restore and close sit at the right with full-bleed backplates, and have rest, hover, pressed and inactive states. They stay fully visible when the title truncates [WIN-TITLE].
- **Corners:** the window and flyouts or dialogs use **8 px**. Buttons, inputs, list items and bars use **4 px**. Corners are **0** when the window is snapped or maximized [WIN-GEOM].
- **Spacing (epx):** 8 between buttons, 8 between a control and its flyout, 8 between a header and its control, 12 between a control and its label, 12 between content areas, 16 from surface edge to text. Controls inside an expander are indented 48 [WIN-SPACE].
- **Type ramp (px / line height):** Caption 12/16, Body 14/20, Body Large 18/24, Subtitle 20/28, Title 28/36, Title Large 40/52, Display 68/92. Font is Segoe UI Variable. Minimums are 12 px regular and 14 px semibold. Use sentence case. Use semibold, not bold. No italics [WIN-TYPE].
- **Motion:** direct entrance 167, 250 or 333 ms with a decelerate curve. Exits are 167 ms and always combined with a fade. Fades are 83 ms. Use the system page transitions and connected animation [WIN-MOTION].

### Electron-specific
- **Native window controls stay native.**
  - macOS: keep the traffic lights (`titleBarStyle: 'hidden'` or `'hiddenInset'`, or `trafficLightPosition`).
  - Windows and Linux: use `titleBarOverlay` rather than hand-drawn min, max and close buttons.
  - Reserve the space with `env(titlebar-area-*)` so content never overlaps the controls.
  - [EL-TITLE]
- **Drag regions:** a custom title bar must be draggable (`app-region: drag`), and buttons inside it must be `no-drag` so they respond. Check in the recording that dragging the header moves the window and that header buttons get hover and click states [EL-DRAG].
- **No web-isms on chrome UI** [EL-DRAG] [practice]:
  - Drag regions use `user-select: none`, so dragging must not highlight text.
  - No text-selection highlight on buttons, menus, sidebar labels or toolbars.
  - Images can't be dragged out as ghost images.
  - No link-style hand cursor on regular buttons. Native desktop buttons keep the arrow pointer.
  - No browser focus rings on mouse click (use `:focus-visible`).
  - No default "Inspect / Back / Reload" web context menu in production.
  - No scroll-bounce of the whole window.
- **No custom context menu on drag regions.** On some platforms, right-click there opens the system window menu [EL-DRAG].
- **No white flash on window open:**
  - Create the window with `show: false` and show it on `ready-to-show`.
  - Set `backgroundColor` to match the app's theme. This matters especially for dark mode.
  - Look for 1 or more blank frames in the recording.
  - [EL-BW]
- **Real application menu with OS conventions.** On macOS, the first submenu is the App menu. Use `CmdOrCtrl` accelerators so that ⌘ on Mac and Ctrl on Windows both work. Shortcut hints shown in menus match the platform [EL-KB] [AP-MENU].
- **Responsiveness:**
  - Main-process work must not block the UI: no sync IPC, no blocking `fs` calls.
  - Startup work is staggered.
  - In the recording, look for a frozen window, a delayed first paint, or a beach-ball or "Not Responding" title.
  - [EL-PERF]
- **Fit each OS:** use the OS font (SF Pro on macOS, Segoe UI Variable on Windows), the correct button order in dialogs, and title or caption controls on the correct side [AP-WIN] [WIN-TITLE] [practice].

---

## Source key and URLs

| Tag | Source | URL |
|---|---|---|
| NN-RT | Nielsen Norman: Response Times, the 3 important limits | https://www.nngroup.com/articles/response-times-3-important-limits/ |
| NN-PROG | NN/g: Progress Indicators Make a Slow System Less Insufferable | https://www.nngroup.com/articles/progress-indicators/ |
| NN-SKEL | NN/g: Skeleton Screens 101 | https://www.nngroup.com/articles/skeleton-screens/ |
| NN-H10 | NN/g: 10 Usability Heuristics | https://www.nngroup.com/articles/ten-usability-heuristics/ |
| RAIL | web.dev: RAIL model | https://web.dev/articles/rail |
| CWV-INP | web.dev: INP | https://web.dev/articles/inp |
| CWV-LCP | web.dev: LCP | https://web.dev/articles/lcp |
| CWV-CLS | web.dev: CLS | https://web.dev/articles/cls |
| CWV | web.dev: Web Vitals overview | https://web.dev/articles/vitals |
| WCAG | W3C WCAG 2.2 Quick Reference | https://www.w3.org/WAI/WCAG22/quickref/ |
| AP-ACC | Apple HIG: Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility |
| AP-BTN | Apple HIG: Buttons | https://developer.apple.com/design/human-interface-guidelines/buttons |
| AP-LAYOUT | Apple HIG: Layout | https://developer.apple.com/design/human-interface-guidelines/layout |
| AP-TYPE | Apple HIG: Typography | https://developer.apple.com/design/human-interface-guidelines/typography |
| AP-TAB | Apple HIG: Tab bars | https://developer.apple.com/design/human-interface-guidelines/tab-bars |
| AP-TOOLBAR | Apple HIG: Toolbars | https://developer.apple.com/design/human-interface-guidelines/toolbars |
| AP-SHEET | Apple HIG: Sheets | https://developer.apple.com/design/human-interface-guidelines/sheets |
| AP-MENU | Apple HIG: The menu bar | https://developer.apple.com/design/human-interface-guidelines/the-menu-bar |
| AP-WIN | Apple HIG: Windows | https://developer.apple.com/design/human-interface-guidelines/windows |
| AP-LAUNCH | Apple HIG: Launching | https://developer.apple.com/design/human-interface-guidelines/launching |
| AP-PROG | Apple HIG: Progress indicators | https://developer.apple.com/design/human-interface-guidelines/progress-indicators |
| AP-MOTION | Apple HIG: Motion | https://developer.apple.com/design/human-interface-guidelines/motion |
| AP-POINTER | Apple HIG: Pointing devices | https://developer.apple.com/design/human-interface-guidelines/pointing-devices |
| AP-LAUNCHDOC | Apple: Reducing your app's launch time | https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time |
| AP-HITCH | Apple: Understanding hitches in your app | https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app |
| AP-HANG | Apple: Understanding hangs in your app | https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app |
| AND-LAUNCH | Android vitals: App startup time | https://developer.android.com/topic/performance/vitals/launch-time (also /google/play/vitals/launch-time) |
| AND-JANK | Android: Slow rendering / frozen frames | https://developer.android.com/topic/performance/vitals/render |
| AND-A11Y | Android: Make apps more accessible | https://developer.android.com/guide/topics/ui/accessibility/apps |
| AND-WSC | Android: Use window size classes | https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes |
| AND-LAYOUT | Android design: Layout basics | https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-basics |
| MDC-MOTION | Material Components Android: Motion (M3 duration tokens) | https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md |
| MDC-TYPE | Material Components Android: Typography (M3 type scale) | https://github.com/material-components/material-components-android/blob/master/docs/theming/Typography.md |
| MDC-NAV / RAIL / FAB / SHEET | Material Components Android: BottomNavigation, NavigationRail, FloatingActionButton, BottomSheet docs | https://github.com/material-components/material-components-android/tree/master/docs/components |
| M3-sec | M3 margins and spacing. m3.material.io renders with JS and could not be fetched; values were cross-checked via SAP Fiori for Android, which builds on M3. Verify at m3.material.io | https://m3.material.io/foundations/layout/applying-layout/window-size-classes ; https://www.sap.com/design-system/fiori-design-android/v26-4/foundations/adaptive-layout/layout-basics |
| WIN-TITLE | Microsoft: Windows app title bar | https://learn.microsoft.com/en-us/windows/apps/design/basics/titlebar-design |
| WIN-TYPE | Microsoft: Typography in Windows | https://learn.microsoft.com/en-us/windows/apps/design/signature-experiences/typography |
| WIN-GEOM | Microsoft: Geometry in Windows 11 | https://learn.microsoft.com/en-us/windows/apps/design/signature-experiences/geometry |
| WIN-SPACE | Microsoft: Content layout and spacing | https://learn.microsoft.com/en-us/windows/apps/design/basics/content-basics |
| WIN-MOTION | Microsoft: Motion in Windows | https://learn.microsoft.com/en-us/windows/apps/design/signature-experiences/motion |
| WIN-TARGET | Microsoft: Targeting | https://learn.microsoft.com/en-us/windows/apps/develop/input/guidelines-for-targeting |
| Fluent 2 | Fluent 2 design system (umbrella for the WIN-* pages) | https://fluent2.microsoft.design/ |
| EL-DRAG | Electron: Custom window interactions | https://www.electronjs.org/docs/latest/tutorial/custom-window-interactions |
| EL-TITLE | Electron: Custom title bar | https://www.electronjs.org/docs/latest/tutorial/custom-title-bar |
| EL-BW | Electron: BrowserWindow (showing the window gracefully) | https://www.electronjs.org/docs/latest/api/browser-window |
| EL-KB | Electron: Keyboard shortcuts | https://www.electronjs.org/docs/latest/tutorial/keyboard-shortcuts |
| EL-PERF | Electron: Performance | https://www.electronjs.org/docs/latest/tutorial/performance |
