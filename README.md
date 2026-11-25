# audit-recording

[![ci](https://github.com/ardalangh/audit-recording/actions/workflows/ci.yml/badge.svg)](https://github.com/ardalangh/audit-recording/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A [Claude Code](https://code.claude.com) skill that audits a **screen recording** of a mobile, web or desktop app.
It reports UI bugs, visual design problems and **measured latency**. Each finding includes timestamps,
frame evidence and a mock-up of the fix.

Claude can't watch video, so a script does the measuring and Claude does the judging. The script reads every
frame's real timestamp and finds where and when the screen changed. It measures how long each action took to
respond and to settle, then cuts labelled frames and zoomed filmstrips. Claude reads those images, works
through a checklist of about 120 checks with platform norms for iOS, Android, web, macOS and Windows, and writes
findings. Each finding has to point at a frame.

The output is a page. Each finding shows the screen with the problem **circled** and a zoomed close-up. Next to
it is the **fix as an HTML/CSS mock-up** of that part of the screen with the change applied. If the app's source
code is in your workspace, the mock-ups use its real colour tokens, fonts and copy, and each fix lists the file
and line to change.

## What it catches

- **Latency:** time from input to first feedback, to the result, and to a settled screen. Also frozen waits with
  no feedback, spinners that run too long, and dropped-frame hitches. Every number is graded against published
  thresholds: 100 ms feedback, 1 s actions, RAIL, INP and the platform's own guidelines.
- **UI bugs:** blank or flashing frames, content that appears and then reverts, layout jumps, states that
  contradict each other across screens, and broken or missing feedback.
- **Design:** hierarchy, spacing and alignment drift, terminology that changes between screens, unlabelled icons,
  contrast that's probably too low, touch-target size, and consistency with the platform.
- **Flow:** dead ends, extra steps, and promises on one screen that the next screen breaks.

## Install

You need **Python 3.9+** and **ffmpeg** (`brew install ffmpeg` or `apt install ffmpeg`). Tested on macOS and Linux.
The scripts use only the Python standard library.

### As a Claude Code plugin (recommended)

```
/plugin marketplace add ardalangh/audit-recording
/plugin install audit-recording@audit-recording
```

To update later, run `/plugin marketplace update audit-recording`.

### As a plain skill

Copy the skill folder into your personal skills (all projects) or a project's `.claude/skills/`:

```bash
git clone https://github.com/ardalangh/audit-recording.git
cp -R audit-recording/skills/audit-recording ~/.claude/skills/
```

The folder follows the open [Agent Skills](https://agentskills.io/specification) format. Tools that read
`SKILL.md` folders can use it too, for example `npx skills add ardalangh/audit-recording`.

## Use

Ask in plain words. The skill triggers on its own:

> Here's a recording of our checkout, `~/Desktop/checkout.mov`. What's wrong with it, and why does it feel slow?

Or call it directly. As a plugin the command is `/audit-recording:audit-recording`; as a plain skill it's
`/audit-recording`.

```
/audit-recording ~/Desktop/checkout.mov focus on the payment step
```

Claude asks one short intake question: what the user is trying to do, the platform, and the recording
conditions. You can answer "unknown". Then it runs the pipeline:

1. **Measure:** `rec_audit.py analyze` writes `recording-audits/<name>/` with `analysis.md`, overview grids,
   state frames and event filmstrips.
2. **Look:** Claude reads the grids, filmstrips and full-resolution frames, and zooms in where it needs to.
3. **Latency:** `rec_audit.py measure --input <t>` times each action.
4. **Review:** the checklist, run against the product's own patterns and its platform.
5. **Code pass** (when the source is in the workspace): checks each finding against the code and builds the
   mock-ups from it.
6. **Report:** `render_report.py` turns `findings.json` into `report/index.html` and `report/report.md`. In the
   Claude desktop or web app the page is published as a private Artifact. Elsewhere, open the HTML file
   locally.

The scripts also work on their own:

```bash
S=~/.claude/skills/audit-recording/scripts
python3 $S/rec_audit.py analyze checkout.mov --platform ios
python3 $S/rec_audit.py measure recording-audits/checkout --input 4.70 --until 7.0 --label "Tap Pay"
python3 $S/rec_audit.py strip   recording-audits/checkout --from 4.6 --to 6.0 --crop 0,1400,1170,600
python3 $S/rec_audit.py frames  recording-audits/checkout --at 5.44,8.09
```

## Get better evidence

- **Show touches and clicks** so input times are measured, not inferred:
  - iOS Simulator: `defaults write com.apple.iphonesimulator ShowSingleTouches 1`;
  - Android: Developer options > Show taps;
  - macOS: Cmd-Shift-5 > Options > Show Mouse Clicks.
- **Record at 60 fps** or higher. Timing resolution is one frame, and the report always states it.
- **Use a release build on a real device** when latency matters. Debug builds, simulators and the recorder
  itself all add delay, so the report says "as recorded".
- Keep recordings under about 3 minutes, or name the time range to focus on.

## Honesty rules

The skill is built to avoid confident nonsense:

- No evidence, no finding.
- Observation comes before interpretation, and causes are labelled as inferred.
- Pixel sizes and colours read from compressed video are estimates and marked "~".
- Layout is judged only on settled frames.
- Brief defects need two or more frames.
- Text it can't read is never guessed.
- Anything a video can't show (screen readers, focus order, haptics, unseen states) goes in a "not assessable"
  list, never in a finding.

The full set of 15 rules is in [`SKILL.md`](skills/audit-recording/SKILL.md).

## Privacy

Everything runs locally. The scripts make no network calls. The rendered page contains frames from your
recording, so the skill asks before publishing recordings of private screens (credentials, other people's
data, messages) and never publishes the raw video. The report page loads its typefaces from Google Fonts.

## Repo layout

```
.claude-plugin/          plugin.json + marketplace.json (this repo is its own marketplace)
skills/audit-recording/
  SKILL.md               the workflow Claude follows
  scripts/rec_audit.py   measurement: analyze, measure, strip, frames
  scripts/render_report.py   findings.json -> report page
  references/            latency thresholds, checklist, platform norms, report format
docs/research/           the research notes the skill was built from
tests/                   smoke test on a synthetic recording (runs in CI)
```

## Contributing

Issues and pull requests are welcome, especially recordings where the measurements are wrong. Before opening
a PR, run:

```bash
bash tests/smoke_test.sh
```

## Credits

The workflow, thresholds and checklist build on prior work. See [`docs/research/`](docs/research) for notes on each
source, including serebano/video-ux-audit, OneRedOak/claude-code-workflows (design-review), Vercel's Web
Interface Guidelines, pbakaus/impeccable, emilkowalski's animation review skill, and published guidance from
Apple, Google (Material, RAIL, Core Web Vitals), Microsoft and Nielsen Norman Group.

## License

[MIT](LICENSE)
