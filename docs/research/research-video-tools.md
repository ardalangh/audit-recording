# Research notes: video-to-frames techniques for a UI/UX/latency audit skill

Scope: what to borrow from existing Claude video skills and from pixel-latency prior art, for a skill that audits an EXISTING screen recording (.mov/.mp4/.webm from mobile, web or desktop) and reports UI, design and latency issues. Everything below was read from source (gh api) unless marked "(blog)" or "(paper)".

---

## 1. serebano/video-ux-audit

Files read: SKILL.md, scripts/timeline.mjs, scripts/report.mjs, scripts/encode.sh, scripts/record.mjs (grep), examples/*/ai-pack/PROMPT.md, examples/2026-11-22-try-page-demo/{README,findings}.md, templates/findings.md.

**What it is.** It is a recorder, not a video analyser. It drives Chrome over CDP (`Page.startScreencast`, jpeg q80, `everyNthFrame:1`) and stores each frame with its wall-clock ms since t0. It also records console, network, longtask and layout-shift events on the same clock. The fused `timeline.md` and the keyframes then go to an LLM in one pass. For an existing video, the useful parts are the review prompt, the finding format, the severity ladder and the noise lessons. The capture itself does not apply.

**Techniques worth copying**
- **One clock for everything.** Frames are named by video time (`mm-ss-mmm.jpg`), and every signal row links to the frame at or before its time (`frameAt(t)`). For us, the equivalent is to name every extracted frame and grid cell by its source PTS in ms, and to cite those names in findings.
- **Keyframe selection for the AI pack** (timeline.mjs):
  - about 1 frame per second (keep a frame if 1000 ms or more have passed since the last kept one);
  - plus the frame at every auto-signal;
  - plus the frame at action/caption time + 300 ms, so the frame shows the response to the action rather than the action;
  - hard cap of 120 keyframes.
  - Borrow this as: a uniform floor + event-anchored frames + a post-input offset frame + a cap.
- **ffconcat with exact per-frame durations** to rebuild a VFR video with real timing (`file 'f.jpg'` / `duration 0.033`), encoded with `ffmpeg -f concat -safe 0 -i frames.ffconcat -fps_mode vfr -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -pix_fmt yuv420p`. This is useful if we ever re-encode an annotated evidence clip.
- **Signal thresholds** (network/perf; for an existing video, only the time thresholds carry over):
  - slow request: 1 s or more is P2, 3 s or more is P1;
  - heavy payload: 500 KB or more;
  - duplicate request: the same call within 2 s, with cache hits skipped;
  - long task: 200 ms or more is P2, 500 ms or more is P1 ("UI frozen");
  - layout shift: CLS 0.05 or more without recent input.
  - The skill's P1 rule is "an action takes over 1 s or a view over 3 s". Reuse it as the latency severity ladder.
- **Severity ladder** (copy nearly verbatim in spirit):
  - P0: data loss, wrong recipient, privacy or security leak, or the core job is impossible.
  - P1: core job broken or misleading, an action over 1 s or a view over 3 s, or two surfaces disagree.
  - P2: friction, wording, cosmetic.
- **Review prompt** (PROMPT.md, paraphrased):
  - Persona: "senior UX + performance reviewer".
  - In ONE pass, produce rows with: ID, severity, title, steps, expected, actual, video time, evidence (frame + event lines), suspected area, UX suggestion, performance suggestion.
  - Then list OPPORTUNITIES and GAPS: missing affordances, dead ends, unclear states, missing feedback, redundant work, things a competitor does better.
  - Rank everything by user impact ÷ effort.
  - "Do not invent: every row must cite a frame or a timeline line." The SKILL.md short form is "no evidence, no row".
- **Post-hoc frame-review checklist.** "Look at the frames around every signal and step, at least once a second." This catches flashes of wrong content, half-rendered states, Markdown or layout flicker, spinners that never stop, and screens that disagree after an action. Its two frame-only findings were a ~0.5 s brand/logo flash on first render (seen across frames 00:00.46–00:01.11) and a stray `*` during streamed Markdown that lasted about 30 ms. Neither left any trace in logs. This is exactly the class of finding our skill must target.
- **Finding table columns** (report.mjs): `ID | Sev | Finding | Steps | Expected | Actual | Video | Screenshot | Suspected area | UX suggestion | Performance suggestion | Found by`. "Found by" (auto-signal vs post-hoc frame review vs live) is a nice honesty column. Keep it as `Evidence type: measured / seen-in-frame / inferred`.
- **"Act like a real user" heuristics** that convert into review questions:
  - Did the obvious path work?
  - After every action, does everything agree (list, counters, header, other panels)?
  - "If you wait, the user waits."
- **Noise vs real (measured).**
  - 18 auto-signals: 11 real (61%), which collapsed into 3 issues.
  - Noise: keepalive/beacon requests flagged never-finished, layout shifts while content streamed in by design, and two different analytics events to the same URL.
  - Before a fix, 42 signals, half false (19 memory-cache hits counted as duplicates, plus open event streams).
  - Lesson: auto-signals are hypotheses. Every one must be checked against its frame before it becomes a finding, and the report should say so. Expect about 40% noise from any automatic detector.
- **Budget data point.** A ~15-minute flow took 55 agent-minutes, cost about $17 and produced 48 findings. One screen took about 10 minutes of review.

**Weaknesses (for our use)**
- It requires live capture via CDP and has no path for an arbitrary recorded file.
- Frame selection is time-only (1/s) with no scene/dedup logic, and no grids, so it is token-heavy at 120 separate images.
- It has no pixel-based latency measurement. Every timing comes from browser events.
- Captions are burned into the video and can cover the very element they point at (their own note).

---

## 2. cportka/claude-plugins — plugins/video-bug-analyzer

Files read: skills/video-bug-analysis/SKILL.md, reference.md, scripts/extract-frames.sh (a 178 KB bash script; read the key sections).

**Defaults** (from the script):
- `--fps 4`; overview `--fps 2 --contact`; zoom `--fps 8`; flicker `--fps 15 --window 0.5`.
- Scene mode `--scene <thr>`, with 0.1 recommended for UI; `--list-scenes` defaults to 0.3.
- Contact sheet: 4 cols × 4 rows, tile width 480 (raised from 320, which was "too small for text/code UIs"); `--text` sets tile width 640.
- Burst frames are 820 px wide ("keeps text legible"). Dense/scene frames are capped at 1280 px (`scale='min(1280,iw)':-1`, never upscale).

**Exact ffmpeg patterns**
- Contact sheet: `ffmpeg -i in.mov -fps_mode vfr -vf "fps=2,scale=480:-1,drawtext=...,tile=4x4" contact_%04d.png`. The `tile` filter spills automatically into contact_0002.png and so on.
- Scene selection: `-vf "select='gt(scene,0.1)',scale='min(1280,iw)':-1" -fps_mode vfr`.
- Listing cut times only: `ffmpeg -i in -vf "select='gt(scene,0.3)',showinfo" -f null -`, then parse `pts_time:` from stderr.
- Timestamp burst: `ffmpeg -ss <t-0.5> -to <t+0.5> -i in -vf "fps=8,scale=820:-1" ts01_%03d.png`, then a before/after strip from the first and last burst frames: `ffmpeg -i first.png -i last.png -filter_complex hstack -frames:v 1 ts01_strip.png`. The strip is "the best artifact for a UI-state-transition bug".
- For a strip of differently sized frames, normalise height first: `[0:v]scale=-2:720[a];[1:v]scale=-2:720[b];[a][b]hstack=inputs=2`.
- Timestamp burn-in: `drawtext=fontfile=<ttf>:text='%{pts\:hms}':x=10:y=10:fontsize=20:fontcolor=yellow:box=1:boxcolor=black@0.5`. For a seeked burst, use the offset form `%{pts\:hms\:<offset>}` so the label shows absolute source time, not time since the seek. The script PROBES drawtext + font first and silently skips labels if they fail.
- Motion timeline: `-vf "fps=<n>,tblend=all_mode=difference,signalstats,metadata=mode=print:file=m.txt" -f null -`, then read `lavfi.signalstats.YAVG` (mean |frame−prev|, 0–255) per frame.
- Stall/hang: the same motion timeline. The longest run with YAVG < 1.5/255 lasting 2 s or more is a STALL ("a dead canvas reads as smooth to a jank detector").
- Stutter/freeze: one decode, `-vf "freezedetect=d=0.1,mpdecimate,showinfo" -an -f null -`. freezedetect is placed before mpdecimate so it sees every frame. `freeze_*` lines give the freeze gaps, and showinfo `pts_time` of the mpdecimate survivors gives unique-content cadence per 0.5 s window. Combining both in one graph was measured 29% faster than two passes.
- Blackdetect: `blackdetect=d=0.1:pic_th=0.98`. Crop away persistent HUD/status bars first or the real blackout is missed. A span sustained to EOF is classed PERMANENT.
- Whiteout: mean luma 220/255 or more, OR 4× or more the clip's own median luma (floored at 140), lasting 0.2 s or more. The relative rule catches flashes in dark-themed apps.
- Content revert (A→B→A within 1.5 s, sampled at 10 fps): catches "text vanished then came back" flicker. Crop to the text region, because looping animations also trigger it.
- Pacing: ffprobe per-frame PTS, then interval_ms with median/p95/max and the worst hitches. This catches jank even when every frame differs.
- `--unique`: mpdecimate survivors = distinct poses + real cadence ("changes every ~66 ms ≈ 15 fps").
- `--ab other.mov`: per-frame SSIM between two captures (`ssim=stats_file=`). Useful for before/after-fix comparisons.
- `--edge right:60`: crop a screen-edge band to check for content cut off at an edge.

**Portrait handling**
- `ffprobe -show_entries stream=width,height`. If h > w, contact sheets drop to `--cols 2`, and to `--cols 1` when `--text`.
- A legibility guard warns when source_width / tile_width > 2.5 ("small UI text may be illegible").
- Report sizes as % of viewport, not px (dpr 2/3 makes device px misleading). CSS vmin = width in portrait.
- For dense text, full-res individual frames at 1–2 fps beat any contact sheet.

**Pitfalls they hit (each "burned us once")**
- ffmpeg ≥ 5.1 uses `-fps_mode vfr`; older builds use `-vsync vfr`. Detect the version.
- macOS recordings report r_frame_rate = 240. That is a timebase, not the content rate, so never treat nominal fps as real fps.
- Static/black pre-roll at the start inflates "choppy" stats. Detect where sustained content begins.
- The motion amplitude floor: whole-frame + downscale quantises subtle motion to ~0. If the peak is under ~3/255, re-run cropped to the region.
- The healthy "playback cadence" header is a measurement of frame timing only. A frozen or wrong-state UI can post perfect cadence.
- "Frames can't see state": if a tracked value changes but nothing near it changes on screen, the cause is off-screen.
- Yuv420 chroma subsampling shifts saturated colours (hot pink reads salmon), so treat palette hexes as approximate. Never audit exact brand colours from a compressed recording.
- `--window` × `--fps` below one frame yields 0 frames; warn about it.
- bash 3.2 on macOS lacks mapfile.

**Reliability matrix** (copy into our report caveats):

| Bug class | Reliability from frames |
|---|---|
| Persistent layout, missing element, wrong text, error modal | High |
| Colour/theme | Medium |
| One-frame flicker, timing/race, few-px diffs | Low (risk of hallucinated detail) |
| Console/network/memory | None |

**Workflow rules worth copying**
- Ask for an approximate timestamp first; it is the biggest accuracy lever.
- Do an overview contact sheet, then zoom bursts. "Tighten the window rather than raising fps across the whole clip."
- Label each finding seen vs inferred, with confidence.

**Weaknesses**
- Huge monolith. Bug-diagnosis oriented (one symptom), not audit oriented (many findings). Scene threshold is a fixed number. No dedup before contact sheets. Labels depend on drawtext, which is missing from Homebrew ffmpeg builds without freetype; it silently skips them.

---

## 3. jordanrendric/claude-video-vision

Files read: mcp-server/src/extractors/frames.ts, analyzers.ts, config.ts, tools/video-watch.ts, video-detail.ts, scripts/measure-tokens.ts, the smart-video-analysis design spec, commands/watch-video.md, agents/frame-describer.md.

**Adaptive fps by duration** (`calculateAutoFps`):

| Duration | fps |
|---|---|
| under 60 s | 2 |
| under 5 min | 1 |
| under 15 min | 0.5 |
| under 60 min | 0.2 |
| otherwise | 0.1 |

The fps can also be derived from a requested sample count: `fps = view_sample / duration`.

**Other defaults**
- `frame_resolution` 512 px wide (`scale=512:-1`), jpeg `-q:v 5`, `max_frames` 100. Resolution is clamped to 128–2048 per segment.
- `ffmpeg -ss <start> -i in -t <dur> -vf "fps=F,scale=R:-1" -frames:v MAX -q:v 5 frame_%04d.jpg`. Note `-ss` before `-i` resets timestamps, so they pass `-t` (duration) rather than `-to`.

**Analyse-before-extract pass.** One decode with only the needed filters, writing per-frame metadata:
- `-vf "scdet=threshold=8,blackdetect=d=0.1:pic_th=0.98:pix_th=0.10,freezedetect=n=-60dB:d=2,siti=print_summary=1,blurdetect,signalstats,metadata=mode=print:file=video_meta.txt" -f null -`.
- scdet threshold 8 (scale 0–100): "8+ correlates with hard cuts; below that handheld motion dominates." For UI recordings that is too high; UI transitions score lower.
- `freezedetect=n=-60dB:d=2` finds frozen spans of 2 s or more.
- Analysis timeout = max(10 min, 2 × duration). On a timeout kill, report `analyzed_until` from the last `time=` in stderr instead of silently returning partial results as complete.

**Segments with per-segment fps/resolution.** Low fps (0.1–0.5) for static parts, 1–3 fps only around scene changes or motion peaks. The extract-vs-view split: extract many frames to disk, then return only `view_sample: N` evenly spaced ones, then specific timestamps. The drill-down rule: "start with a 3–5 s window, view_sample 3 (first/middle/last), treat frame viewing like a binary search, never view all extracted frames at once."

**Manifest/cache.** Keyed by SHA-256 of the first 64 KB + file size. Frames are organised by resolution, with timestamp as the dedup key, so a follow-up question never re-extracts or re-views frames already in context.

**Token formula** used in measure-tokens.ts: image tokens ≈ (w × h) / 750, plus the per-frame header text tokens.

**"descriptions" mode.** A cheaper Sonnet subagent (frame-describer) turns frames into one-to-three-sentence text per frame, covering people, on-screen text/UI, objects, setting and change vs the previous frame ("describe, don't interpret"). This trades fidelity for tokens. It could work for a first pass over long recordings, but it loses the visual detail a design audit needs.

**Weaknesses**
- Segment timestamps are rounded to whole seconds (`formatHMS(Math.round(t))`), and the manifest dedups by HH:MM:SS. That is useless for latency (sub-second) work, so we must keep ms.
- No dedup of near-identical frames, no grids. 512 px is too small for phone UI text.
- Timestamps are computed as index/fps, not read from PTS, which is wrong for VFR screen recordings.

---

## 4. guimatheus92/mcp-video-analyzer

Files read: src/processors/frame-dedup.ts, frame-extractor.ts, frame-ocr.ts, image-optimizer.ts, src/config/detail-levels.ts, skills/video/SKILL.md.

**Scene detection with a coverage guarantee.** This is the best single select expression found:
- `select='gt(scene,0.1)+isnan(prev_selected_t)+gte(t-prev_selected_t,SPACING)',showinfo` with `-fps_mode vfr`, where SPACING = duration / maxFrames.
- It keeps every cut at a 0.1 threshold, always keeps the first frame, and adds a frame whenever SPACING seconds pass without one. A static screen recording therefore still gets uniform coverage in one pass.
- When over the cap, `pickSceneFrames` buckets by SPACING and keeps the LAST frame per bucket, so a cut inside a bucket wins over a filler.
- If no cuts are found, fall back to 1 fps dense (and say so in a warning: "better for static clips and on-screen text OCR").

**Real-source-frame bursts.** `select='gte(t-FROM+0.000001,selected_n/FPS)',showinfo`. It picks actual source frames at the requested rate rather than letting `fps=` duplicate or retime frames. It never returns more frames than exist, and timestamps come from showinfo `pts_time` with the stream time base ("source-pts" timing origin). This is important for latency: you want true PTS, never synthetic times.

**Frame budget by duration** (`resolveMaxFrames`, standard level):

| Duration | Max frames |
|---|---|
| 30 s or less | 12 |
| 60 s or less | 20 |
| 180 s or less | 30 |
| 600 s or less | 45 |
| otherwise | 60 |

The detailed level is 1 fps capped at 60. The brief level extracts 0 frames.

**Dedup**
- dHash: greyscale resize to 9×8, compare each pixel to its right neighbour, giving 64 bits. Hamming distance ≤ 5 means a duplicate of the LAST KEPT frame (not the previous frame), so slow drift accumulates and is eventually kept.
- Black frames: drop frames with mean RGB < 10.
- **OCR-aware dedup** (`dedupeKeepingTextChanges`): keep a frame if it is visually different OR its normalised OCR text changed. Motivation: a coarse perceptual hash barely registers a small text change (a price, a counter, a toast), and plain dedup would merge frames that carry different text. This is very relevant to UI audits: a counter update, validation message or toast is a small-area change.

**OCR.** tesseract.js `eng+por`. Preprocess: greyscale, 2× upscale (capped at 3000 px), normalise, mild sharpen, PNG. Deliberately no hard binarisation ("destroys thin text over photos"; Tesseract does Otsu itself). Keep only results with more than 3 characters and confidence above 50.

**Width.** Emitted frames are capped at 800 px by default. The SKILL warns that this turns a 1920×1080 screencast into 800×450 and drops 15 px UI text below legibility. `maxWidth: 1568` is the middle ground and 0 keeps native resolution. "Raise it for the close read, not for the overview."

**Weaknesses**
- dHash at 9×8 is blind to small UI changes, which is why they bolted on OCR.
- 800 px default is too small for dense UI.
- No grids, so each frame is a separate image.
- No latency measurement.

---

## 5. andrewii23/ii23-skills — skills/video-understand

Files read: SKILL.md, scripts/frames.py, scripts/index.py (grep), ADRs 0001–0008, docs. This is the most rigorous of the set, with measured decisions.

**Grid packing (ADR 0001)**
- 64 frames read individually ≈ 12.5k tokens; the same 64 as one grid ≈ 1.9k (about 7× cheaper).
- Claude downscales images to a 1568 px long edge before tokenising (`TOKEN_CAP_LONG_EDGE = 1568`). A grid larger than that costs the same ~1.85–1.9k tokens however many cells it holds. "Cell count is a resolution decision, not a cost one."
- Measured legibility on 720p (landscape):

| Cells | px per cell | Legible for |
|---|---|---|
| 16 | ~392 | small UI text, timestamps, labels |
| 36 | ~261 | expressions, fine action |
| 64 | ~196 (default) | plot/recap; big captions readable |
| 100 | ~157 | skim; small text lost |

- Player-UI text needs about 392 px/cell. For a UI audit, use 9–16 cells per grid. Never use 64.
- Their own note: papers (IG-VLM, Video Panels) cap at 6 frames or 2×2 grids. They tested 36/64/100 directly on Claude and found 64 legible for big content.

**Exact grid command** (frames.py `build_grid`)
- Stage frames as g_000.jpg…; then `ffmpeg -i g_%03d.jpg -i l_%03d.pgm -filter_complex "[0:v]scale=CW:CH,setsar=1[c];[c][1:v]overlay=0:0,tile=COLSxROWS:margin=6:padding=4:color=white" -frames:v 1 grid_000.png`.
- Without labels: `-vf "scale=CW:CH,setsar=1,tile=COLSxROWS:margin=6:padding=4:color=white"`.
- Cell width defaults to 480. Frames are pre-extracted at `scale=480:-2`, jpeg `-q:v 4`.
- The last grid is shrunk to its own cols/rows so it has no blank cells. Each grid's cols/rows are recorded in the manifest.

**Timestamp labels without drawtext (ADR 0006)**
- Homebrew ffmpeg has no drawtext (no freetype). They render each label as a tiny PGM image with a built-in 5×7 bitmap font in pure Python and `overlay` it top-left.
- Labels in one grid are padded to equal width: ffmpeg re-initialises overlay when the input frame size changes, and "a grid mixing `9` and `10` came out holding only its second half".
- Label format is `MM:SS.d`. Exact `t_ms` lives in a manifest.json per cell.
- Rule: "cells are NOT evenly spaced, so never infer a time from a cell's position; read the stamp or the manifest."
- For us: pure-Python PGM labels (or Pillow if available) are the robust path. Probe drawtext and fall back to them.

**Portrait (`grid_shape`).** Landscape cells give a near-square count layout (cols = ceil(sqrt(cells))). For portrait cells (aspect = w/h < 1), use cols = round(sqrt(cells / aspect)), so a 9:16 phone grid gets more columns and the whole grid stays near-square instead of becoming a tall strip that the 1568 px downscale crushes. Cell width for portrait = cell_width × aspect, keeping even dimensions. Aspect is measured on an EXTRACTED frame (after ffmpeg applied rotation metadata), so a phone clip stored landscape-with-rotate is handled. Effective per-cell px after downscale = min(cell_w, cell_w × 1568 / grid_long_edge), printed on stderr.

**Dedup.** A 16×16 grey thumbnail of every frame in ONE ffmpeg pass: `ffmpeg -start_number N -i f_%05d.jpg -vf "scale=16:16,format=gray" -f rawvideo -`. Then take the mean absolute per-pixel difference vs the LAST KEPT frame; 2.0 or less (0–255 scale) is a duplicate. Measured: idle frames 0.1–1.4, real cuts/events 15–43. Fail-open: if counts mismatch, skip dedup rather than drop frames. Shot "anchor" frames are exempt from dedup.

**Adaptive cut detection (ADR 0007)**
- Per-frame scene score on EVERY frame at 160 px: `[0:v]scale=160:-2,split[a][b];[a]select='gte(scene,0)',metadata=print:key=lavfi.scene_score:file=scene.txt[sa];[b]fps=SAMPLE,signalstats,blurdetect=block_width=16:block_height=16,metadata=print:file=stats.txt[sb]`.
- Rule (PySceneDetect AdaptiveDetector idea):
  - a cut is certain at score ≥ 0.30;
  - otherwise it is a cut if the score is ≥ 0.12 AND at least 3× the mean of the 4 frames on either side;
  - drop cuts within 0.4 s of the previous one.
- Measured: a fixed `scene>0.3` found 0 of 32 hand-marked cuts; adaptive found 30 of 32 with 0 false cuts. "Cuts are one frame wide, so sampling at a few fps would step over them."

**Extractor choice (ADR 0002).** Keyframe-only decoding (`-skip_frame nokey`) is great for edited film. For screen recordings, I-frames track the encoder, not the content: a 44 s 120 fps screen recording gave 1.02 keyframes/s, only 71% distinct, and they missed the action. Decide by measuring the fraction that survives dedup (trust keyframes only if there are 0.15/s or more and 80% or more are distinct). For screen recordings, don't use keyframes.

**Budget (ADRs 0003, 0006)**
- Budget total frames, not fps. Default 512; the shot-driven default rises to the shot count, capped at 2048.
- Fill density: 4/s under 1 min, 2/s under 5 min, 1/s beyond.
- Thin EVENLY across the range (even_sample, keeping first and last). Never truncate the tail, and report thinning in the manifest (`frames_thinned_for_budget`) and on stderr. "Silent truncation would read as 'this is everything'."
- One frame per shot is the floor. Fill frames skip anything within 0.3 s of an anchor.

**Sharpest/lit frame (ADR 0008).** Pick a representative frame only where mean luma is 25–235 AND YHIGH−YLOW ≥ 60, because black or flat frames read as "sharp" to blurdetect. Use the same filter when picking the frame that represents a UI state (it avoids mid-transition fades).

**Cue frames.** `--at 4:32,7:10 --cells 16` grabs exactly those instants, with no dedup.

**Reading rules**
- Read every grid in one message (parallel Read calls).
- "Zoom, don't re-read": re-run on `--start/--end` with fewer cells rather than cropping stills.
- The "plausible story" failure mode: frames let you build a coherent, confident, wrong narrative. Treat causal stories as hypotheses that need corroboration.

**Stated limits.** Grids cannot show continuous motion (easing, velocity, overshoot); "a 250 ms ease is one frame at 4 fps". No frame-exact timing.

**OCR screening (ADR 0005).** Full resolution, confidence floor 0.3, and a "max 8 chars" noise gap (noise ≤ 4 chars, smallest real overlay 18). On macOS, Vision via a compiled Swift helper (needs full language codes like th-TH) with tesseract as fallback.

**Weaknesses (for our use)**
- Built for film/episodes. The default 64 cells is far too coarse for UI text.
- Scene thresholds are tuned for film cuts, not UI micro-changes.
- No latency measurement.
- The heavy transcript emphasis is irrelevant for most silent UI recordings.

---

## 6. reymerekar7/rm-skills — skills/video-performance-analyzer

Files read: SKILL.md, scripts/analyze_video.py.

**What it is.** Not a frame pipeline. It uploads the MP4 to the Gemini Files API and asks `gemini-3-flash-preview` (native video understanding) one big structured prompt: transcript with `[OVERLAY: ...]`, `[MUSIC: ...]` and `[CUT: ...]` inline tags; a visual/audio breakdown; hook analysis; a stakes map table; and scoring tables. It is aimed at social-video virality, not UI.

**Ideas worth borrowing**
- Inline event tags in the transcript-like timeline (`[CUT:]`, `[OVERLAY:]`). Our equivalent is `[TAP @x,y]`, `[SPINNER]`, `[TOAST "…"]` and `[NAV → screen]` tags in a per-interaction timeline.
- "Visual change frequency (changes per minute)" as a metric.
- Scoring tables per dimension (Strong / Moderate / Weak) followed by 3–5 "why" bullets.
- "Generic observations are useless. Quote exact words": require quoting the on-screen text in findings.
- Optional escape hatch: a model with native video input (Gemini) could provide a second opinion on motion and animation quality that stills can't show. Privacy caveat: it uploads the video to Google.

**Weaknesses.** It sends the whole video off-box, gives no timing precision, and has nothing reusable for frames or latency.

---

## 7. Blogs

**stonebergdesign.com/blog/screen-recording-skill** (blog)
- Scene detection threshold **0.1 "tuned for UI work"**. Standard film thresholds miss modal opens, spinners and hover changes.
- Fall back to uniform 1 fps when the recording is static enough that scene detection doesn't fire.
- Read every extracted frame plus a contact-sheet overview.
- Dropped `drawtext` because Homebrew ffmpeg lacks libfreetype and drawtext fails silently. They documented this rather than shipping broken labels.
- Output structure: starting UI state → what changes and when → end state.
- An optional "focus" second argument. If it is missing, the skill ASKS before running ffmpeg, and "general overview" is a valid answer.
- Frames go to `screen-recordings/` in the project (not /tmp) so they persist.
- Clips under 3 minutes work best. Suggest a QuickTime trim for longer ones.

**danielthegoldman.com/guides/claude-watch-videos** (blog; documents bradautomates/claude-video `/watch`)
- Controls: `--max-frames N` (the main context cost), `--resolution 1024` for small text, `--start/--end` focused ranges, `--fps F` with a 2 fps ceiling, `--detail balanced`.
- "Scene-aware images, auto-scaled by the video's length." Under 10 minutes gives the best coverage.
- Honesty rules for bug recordings: treat visible steps with timestamps as observations, and causes as separate claims that need checking. "Sampled frames can miss brief events." Missing transcript is not evidence of silence. If it can't be reproduced, report what remains unverified.

---

## 8. Prior art: pixel-based latency and input detection

### 8a. WebPageTest / browsertime visualmetrics.py

Read: sitespeedio/browsertime `visualmetrics/visualmetrics-portable.py`, 2255 lines. It is the canonical "visual progress from video" implementation. The original WPO-Foundation/visualmetrics repo returned 404; the catchpoint/WebPageTest.agent copy is equivalent.

**Pipeline** (`video_to_frames`): find the viewport → extract frames → optionally remove frames before or on an "orange" sync frame → find render start → adjust frame times → eliminate duplicate frames → crop viewport → per-frame histograms → metrics.

**Extraction:** `ffmpeg -v debug -i video -fps_mode passthrough -vf "crop=W:H:X:Y,scale=iw*min(400/iw\,400/ih):ih*min(400/iw\,400/ih),mpdecimate=0:64:640:0.001" img-%d.png`.
- The `keep pts:… pts_time:…` lines in the `-v debug` stderr give the true PTS of each kept frame. They rename each file to `video-<ms>.png`, so the timestamp is the filename.
- Thumbnail size 400 by default.
- mpdecimate with frac=0.001 means "keep on almost any change": they want every distinct frame, not a sample.
- Fallback: `-vsync 0` when `-fps_mode` is unrecognised.
- Caveat for us: newer ffmpeg added a `keep` option to mpdecimate, which may shift positional args. Use named options: `mpdecimate=max=0:hi=64:lo=640:frac=0.001`.
- Get the filter name dynamically by checking `ffmpeg -filters` for `*decimate` "Remove near-duplicate frames".

**Pixel compare** (`frames_match(img1, img2, fuzz%, max_differences, crop, mask)`): per-pixel, all three channels within fuzz × 255 (numpy isclose). A match means the number of differing pixels is ≤ max_differences.

**Render start / first visual change:** compare each frame to the FIRST frame with fuzz 10% and 0 differing pixels allowed, inside a crop that excludes the edges.
- top max(10 px, 3% of height); right margin max(10, 4% of width); bottom margin max(24, 4% of width).
- This removes scrollbars, browser chrome and overlaid status text.
- Every frame that still matches is deleted as pre-render. The first non-matching one is the first visual change.
- `--renderignore N%` masks a centred rectangle of N% of the frame, used to ignore a central spinner when looking for render start. That is a very relevant trick.

**Duplicate elimination** (crop: top 4% of height, right 4%, bottom 6% of width):
1. From the start: drop frames that match the blank first frame (fuzz 10%, 0 pixels).
2. From the END, walking backwards: drop frames matching the final frame (fuzz 15%, up to 5 differing pixels, "noise around text"). This finds the true last visual change.
3. With `--noisetolerance P`: drop frames differing from the last KEPT frame by ≤ max(5, W×H×P%) pixels at fuzz 15%. This exists because browsers re-rasterise text long after visual completion, leaving sub-pixel noise that pollutes Last Visual Change. Comparing to the last kept frame (not the previous one) keeps slow real changes once the accumulated difference crosses the allowance.

**Visual progress** (`calculate_frame_progress`):
- Build per-frame RGB histograms, excluding near-white pixels (all channels ≥ 250).
- progress(frame) = Σ_channels Σ_bins min(|cur−first|, |final−first|) / Σ |final−first|, floored to %.
- The histogram approach is deliberately position-insensitive (tolerates small shifts).
- No fuzz here, by design.

**Speed Index** = Σ elapsed × (1 − progress_prev), over kept frames.

**Metrics:** First Visual Change = time of histograms[1] (the first kept frame after render start); Last Visual Change = time of the last kept frame. Visually Complete 85/95/99 = the first time progress reaches that %. Perceptual SI uses SSIM vs the final frame; Contentful SI uses Canny edge counts (edges with 10%/30% hysteresis thresholds of the blurred min/max).

**Key-colour frames** detect sync frames of a known colour (e.g. orange) by fraction of pixels in a colour range. Analogy for us: detect a tap indicator or a known highlight colour.

**Diff visualisation:** `diff_<ms>.png` dims the current frame toward white and paints changed pixels red (threshold: sum of channel deltas > 30). `instability.png` heatmap: how many times each pixel changed, amber (once) → deep red (10 or more), on a fixed scale. "A page that paints once is all amber; re-rasterising text shows as red speckle." Both are great evidence images for an audit (a jank/layout-thrash heatmap).

**What to borrow:** true-PTS extraction with mpdecimate; edge-cropped comparison; first visual change by comparing to the baseline frame; last visual change by walking backwards from the settled frame with a noise allowance; histogram progress for "% visually complete"; the noise-tolerance pass against the last kept frame; red-diff and instability heatmaps as evidence.

### 8b. MobileGUIPerf (paper, arXiv 2508.01337; no code released)

- **Input marker:** Android "Show taps" overlay, a semi-transparent circle. Detected with a Faster R-CNN from V2S, trained on 15k synthetic screenshots with overlaid indicators.
- **Gestures:** consecutive detections are grouped into one interaction. Tap if the indicator's bbox centre moves less than 10 px between its first and last frame, otherwise swipe.
- **Response and finish:** SSIM between consecutive frames inside each interaction window (from the first indicator frame to just before the next indicator), then Isolation Forest anomaly detection on the SSIM series. Response frame = first anomaly (with an unpublished offset so button-dim highlights don't count as "response"); finish frame = last anomaly. RT = t_resp − t_start and FT = t_fin − t_start, both from PTS.
- **Capture:** scrcpy at 60 fps. scrcpy added about +16 ms to RT and +51 ms to FT vs a camera baseline.
- **Accuracy:** interaction detection P 0.96 / R 0.93; RT exact in 92% of cases (MAE 1.2 frames ≈ 33 ms); FT exact in 86% (MAE 5.2 frames ≈ 198 ms).
- **Alert thresholds used:** RT > 100 ms, FT > 1000 ms.
- **Failure modes:**
  - ads, banners and looping animations inside the window extend the finish time or cause false responses;
  - a missed following tap merges two interactions and inflates FT;
  - video-heavy apps score worst.
- **Takeaways:** (1) define the window as input → next input; (2) distinguish "feedback" (button highlight) from "response" (substantive change); (3) mask known animated regions before computing "finish".

### 8c. stenyak/inputLagTimer (code read)

Two user-drawn rectangles: an input ROI and an output ROI. Motion = frame-diff sum inside each ROI (optionally on Canny edges). Latency = time from input-ROI motion crossing its threshold to output-ROI motion crossing its threshold (window ≤ 700 ms).

**Adaptive threshold:**
- normalise the current diff by the rolling average;
- compute "instability" = the mean absolute deviation of the normalised history;
- score = max(0, norm − instability) / (0.2 + 1.0 × instability).
- Trigger values are fed back into history at only 10% weight (0.5 for above-average non-triggers), so spikes don't raise the baseline.

This is a clean, cheap way to auto-tune motion thresholds per ROI in noisy footage. Its tips: higher fps gives finer latency; avoid duplicate filler frames from cameras that can't hit the target fps; and top-to-bottom scan-out skews timing by position.

### 8d. vsee/jlagmarker (README read; IISWC'14 best paper)

Android interaction-lag profiling from video. Annotate once: for each input, the tool suggests candidate "lag end" frames and a human picks one, which produces a detector configuration. Later runs of the same workload then find lag ends automatically, so system configurations can be compared. Takeaway: "end of lag" is ambiguous, so let the human or Claude confirm the settle frame from a short filmstrip rather than trusting the pixel rule blindly.

### 8e. Showing input in recordings (platform knowledge, not read from a repo)

- **Android:** `adb shell settings put system show_touches 1` draws a white/grey circle per touch. `pointer_location 1` draws crosshairs plus coordinate text in a top bar; the text is OCR-able, but the bar pollutes diffs, so crop it. Note: `adb shell screenrecord` is effectively VFR and emits frames only when the screen changes. PTS gaps mean "static", and you must use PTS, never index/fps.
- **iOS Simulator:** `defaults write com.apple.iphonesimulator ShowSingleTouches 1` shows touch circles. `xcrun simctl io booted recordVideo` is VFR.
- **iOS device:** no built-in show-touches; AssistiveTouch is not equivalent. Expect no input marker, so infer input from the UI.
- **macOS:** the Cmd-Shift-5 recording Options include "Show Mouse Clicks", which draws a black ring at the cursor on click. Without it, the cursor is visible but clicks are not. Infer a click from the cursor stopping, followed by a control highlight or change near the cursor. macOS recordings have r_frame_rate 240 (a timebase).
- **Web (Chrome DevTools recorder, Playwright):** usually no cursor at all.
- For a skill that receives EXISTING videos, input detection must be multi-strategy:
  1. a touch/click indicator if present (template/colour blob detection; a key-colour histogram as in visualmetrics);
  2. a keyboard caret or typed-text appearance;
  3. a small-area localised change (button highlight/pressed state) preceding a big change;
  4. Claude marks the input frames from a labelled filmstrip.
- Always tell the user that recording with show-touches / show-clicks makes latency numbers far more reliable.

---

## 9. Recommended pipeline (synthesis)

Design stance:
- **Scripts measure and Claude judges.** Every pixel-derived number is a hypothesis to verify on frames, which means expecting about 40% noise as in video-ux-audit.
- **Timing always comes from source PTS in ms**, never from index/fps (screen recordings are VFR).
- **Design and UI judgement happens on readable frames.** Grids are for orientation and flow, and full-resolution singles are for text and detail.

### 9.0 Probe
- Run `ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,avg_frame_rate,nb_frames,codec_name:stream_tags=rotate:stream_side_data=rotation:format=duration -of json in.mov`.
- Compute the displayed orientation after rotation (or measure an extracted frame, as ii23 does). Classify as phone-portrait (h > w, aspect ~0.46–0.6), tablet, or desktop/landscape.
- Compute the REAL frame rate from PTS deltas: `ffprobe -select_streams v -show_entries frame=pts_time -of csv=p=0` (or packet=pts_time for speed). Report median interval, p95 and gaps. Flag r_frame_rate 240 / VFR as a timebase only.
- Detect the frame-rate class and state the latency resolution limit: at 30 fps (33 ms per frame) any latency is ±33 ms, and at 60 fps ±17 ms. A recording that emits only on change (Android screenrecord, simctl) has exact change times but no "nothing happened" frames.
- Ask for (or accept as an argument) a focus/question and the approximate timestamps of known problems, as stoneberg and cportka do. "General audit" is valid.

### 9.1 Masks (do this before any diffing)
Build a static-region mask from the platform class:
- **Phone:** status bar (top ~5–7% of height: clock, battery, signal) and home indicator (bottom ~3%).
- **Desktop:** the menu-bar clock, and the cursor if not wanted.
- **Web:** the browser chrome strip.

Also auto-detect "always-changing" regions: per-pixel change frequency over the whole clip (the visualmetrics instability-heatmap idea). Pixels that change in more than ~50% of frames are a clock, video, carousel or ad, so mask them for settle detection, and report them separately as "continuously animating region".

The ffmpeg way to apply a rectangular mask is `drawbox=x:y:w:h:color=black:t=fill` before diff filters, or crop to the content area. Keep the crop in the manifest so findings can map back to full-frame coordinates.

### 9.2 Change timeline (one cheap decode; the backbone for everything)
- Run one ffmpeg pass on the masked/cropped video, downscaled small for speed. Compute the per-frame change magnitude vs the previous frame, the scene score, and real PTS:
  `ffmpeg -i in -vf "drawbox=...:t=fill,scale=320:-2,format=gray,split[a][b];[a]select='gte(scene,0)',metadata=print:key=lavfi.scene_score:file=scene.txt[x];[b]tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=diff.txt[y]" -map "[x]" -f null - -map "[y]" -f null -`.
  The exact form may need two outputs as shown, or two runs; check it on target ffmpeg versions. `-fps_mode passthrough` keeps every source frame.
- YAVG from tblend difference (0–255) is the "how much changed" signal. Calibrated reference points:
  - cportka's stall threshold is < 1.5/255;
  - ii23's 16×16 thumbnail dedup has idle at 0.1–1.4 and real events at 15–43 (mean abs diff).
- Better for UI, because small changes matter: the CHANGED-PIXEL FRACTION, i.e. the count of pixels whose difference is over a per-pixel threshold (visualmetrics fuzz 10–15%, about 25–38 levels; WPT diff images use a channel-delta sum > 30). Mean YAVG dilutes a small toast or spinner into the noise floor. Implementation: `tblend=all_mode=difference,format=gray,lut=y='if(gt(val,30),255,0)',signalstats` gives YAVG/255 = changed fraction. This lut trick is my own suggestion, not taken from any of the repos.
- Optionally compute a coarse per-cell change grid (for example 8×16 cells for a phone) to localise WHERE change happened: crop tiles, or downscale to 8×16 and diff the raw bytes in Python. This is what lets the script say "change at the top-right" or "only a 40×40 px region is changing" (a spinner).
- Smooth with the inputLagTimer adaptive threshold (rolling baseline + instability compensation) or a simple floor: changed fraction > 0.2% of the content area, or more than N pixels where N = max(5, 0.01% of area), following the visualmetrics noise-tolerance idea.

### 9.3 Frame extraction: scene + interval, true PTS
- **Overview candidates:** `ffmpeg -i in -fps_mode vfr -vf "select='gt(scene,0.08)+isnan(prev_selected_t)+gte(t-prev_selected_t,S)',showinfo,scale=W:-2" -q:v 3 cand_%05d.jpg`. Here S = duration / overview_budget (guimatheus' coverage trick), and the threshold of 0.08–0.1 suits UI (stoneberg and guimatheus use 0.1; film uses 0.3, which misses modals and spinners). Parse `pts_time` from showinfo stderr and rename files to `t_<ms>.jpg`.
- **Better:** drive selection from the 9.2 change timeline instead of `scene`. Apply the ii23 adaptive rule on the changed-fraction series: an event is certain above a hard level, or a spike ≥ 3× the local mean of ±4 frames above a floor, with a 0.15–0.4 s min gap.
- **For each detected change event, take three frames:** the frame BEFORE the change (last stable), the FIRST changed frame, and the SETTLED frame (see 9.6). Before/after pairs are the core evidence unit (cportka's strip).
- **Extract specific instants with real source frames:** `ffmpeg -ss T -i in -frames:v 1 -q:v 2 out.jpg` for single frames. For bursts, use guimatheus' `select='gte(t-FROM+0.000001,selected_n/FPS)'` with showinfo, which never fabricates duplicates.
- **Extraction width:**
  - Grid cells: extract at the cell width you'll tile at.
  - Detail frames: native resolution, capped so the long edge is ≤ 1568 px (`scale='if(gt(ih,iw),-2,min(1568,iw))':'if(gt(ih,iw),min(1568,ih),-2)'`). A 1170×2532 iPhone frame becomes ~724×1568, which keeps 12 pt text legible; a 2880×1800 Mac frame becomes 1568×980.
  - Never upscale.
  - Verify the 1568 px figure against current Claude vision docs for the model in use; newer models may accept larger images.

### 9.4 Dedup
- **Primary:** the ii23 16×16 grey-thumbnail mean-abs-diff vs the LAST KEPT frame, threshold ~2.0, done in one ffmpeg rawvideo pass. It is fast, stdlib-only and fail-open.
- **Problem:** 16×16 and dHash both miss small UI changes (a counter, toast, validation text, checkbox). So also keep a frame if (a) the 9.2 changed-pixel fraction since the last kept frame exceeds ~0.1% with a localised cell hit, or (b) the OCR text changed (guimatheus `dedupeKeepingTextChanges`; tesseract optional, only where available).
- **Never dedup** event anchors (before/first-change/settled frames), user cue timestamps, or the first and last frame.
- Drop near-black or flat frames (mean luma < 10–25 or YHIGH−YLOW < 60) from "representative" picks, but report them as findings if they last more than 100 ms mid-flow (a blank flash). Use blackdetect `d=0.1:pic_th=0.98` with status-bar crop, and whiteout at 4× the median luma.
- Report counts in a manifest: extracted, deduped, thinned for budget (ii23: never silent).

### 9.5 Contact sheets / grids and timestamp labels
- **Two tiers:**
  - (a) A FLOW OVERVIEW grid: one cell per distinct UI state (dedup survivors + anchors), for story, navigation and consistency review.
  - (b) DETAIL singles or small grids for text and design review.
- **Cells per grid by platform** (based on ii23's measured px/cell and the 1568 long edge):
  - **Phone portrait:** 6–8 cells per grid, as 4×2 or 3×2 (portrait cells, so more columns: use ii23 `cols = round(sqrt(cells/aspect))`). Per-cell height of about 700–780 px keeps phone UI text readable. 12 cells (6×2) is the maximum for flow-only review.
  - **Desktop landscape:** 4 cells (2×2) gives ~780 px wide per cell; 9 cells (3×3) gives ~520 px, flow only. For text, use singles. Never use 64.
  - **Tablet:** 4–6.
- **Tile command:** `ffmpeg -i c_%03d.jpg -filter_complex "[0:v]scale=CW:CH,setsar=1[c];[c][1:v]overlay=0:0,tile=COLSxROWS:margin=6:padding=4:color=white" -frames:v 1 grid_000.png`. The second input is the label image sequence. The last grid is shrunk to its own shape; record cols, rows and cells[i].t_ms in a manifest.
- **Labels:**
  - Probe drawtext once: `ffmpeg -f lavfi -i color=c=black:s=64x32 -vf "drawtext=text='x':fontfile=..." -frames:v 1 -f null -`.
  - If it works, burn `MM:SS.mmm` (ms precision; latency work needs it) with `drawtext=fontfile=F:text='%{pts\:hms\:OFFSET}':x=8:y=8:fontsize=H/40:fontcolor=white:box=1:boxcolor=black@0.6`.
  - Else use ii23's bitmap-font PGM overlay, padded to equal width per grid.
  - Also burn a short cell index (#12) so findings can cite "grid 2 cell #12 @ 00:14.233".
  - Put labels in a corner that is usually static (top-left over the status bar on phones is fine, since it is masked anyway), or add a label strip with `pad=iw:ih+28:0:28` so nothing in the UI is covered (video-ux-audit's lesson about captions hiding content).
- **Before/after strip** for every finding: `[0][1]hstack` (or vstack for landscape desktop), heights normalised. Optionally add the visualmetrics-style red diff image. ffmpeg: `[0][1]blend=all_mode=difference` then threshold, or Pillow.
- **Read all grids of a tier in one message** (parallel Read). Zoom by re-extracting a narrower window, not by re-reading.

### 9.6 Pixel-based latency measurement (per interaction)
Define each interaction window from input moment t_in to the next input (MobileGUIPerf). Within it:

1. **Input moment t_in.** Multi-strategy, best first:
   - (a) A touch/click indicator appears: Android show_touches circle, Simulator touch dot, macOS "show mouse clicks" ring. Detect it as a new small roughly circular blob of a consistent colour in a few frames; a template or colour-range match is fine (the visualmetrics key-colour idea). Tap vs swipe: indicator centre moves < 10 px.
   - (b) A pressed/highlight state: a small localised change (< ~2% of area) under the cursor or finger, immediately preceding the bigger change. The MobileGUIPerf lesson: this is FEEDBACK, not RESPONSE. Measure it separately as "input acknowledgement time".
   - (c) The keyboard: key-press popups or new characters in a field.
   - (d) Fallback: Claude marks t_in from a dense labelled filmstrip (jlagmarker-style human-in-loop), ±1 frame.
   - Always record which method was used. Confidence: indicator = high, inferred = medium/low.
2. **First visual response t_first:** the first frame after t_in (excluding the indicator's own pixels and the feedback-highlight region) whose changed-pixel fraction vs the pre-input baseline frame exceeds the noise floor. This is the visualmetrics render-start method: compare against the BASELINE, not the previous frame, with edge-cropped margins and fuzz 10%.
3. **Visually settled t_settle:** walk BACKWARD from the end of the window (or from the next input) and find the last frame that differs from the final stable frame by more than the noise allowance. This is visualmetrics' backwards Last-Visual-Change pass at fuzz 15% with a small pixel allowance, plus the noise-tolerance pass against the last kept frame. Require the settled state to hold at least 300–500 ms (or until the next input) to count as "settled". Exclude masked always-animating regions.
4. **Visual progress curve:** the histogram progress from baseline → final within the window (visualmetrics `calculate_frame_progress`). Report time to VC85 / VC95 / VC100 and an interaction-level Speed Index (Σ Δt × (1 − progress)). A long tail from 85 to 100 usually means late-loading images or layout shifts, which are good design findings.
5. **Spinner / busy detection:** between t_first and t_settle, a SMALL localised region (< ~3% of area, roughly constant bbox) changes every frame or periodically while the rest of the screen is static. Use the per-cell change grid; the periodicity check is autocorrelation of the region's diff series, or A→B→…→A repeats via thumbnail hashes. Classify each wait segment as:
   - **spinner/progress** (localised periodic change);
   - **skeleton/shimmer** (a large region with low-amplitude sweeping change);
   - **frozen** (zero change above floor for 250 ms or more after input, with no indicator of progress). This is the worst case: the user gets no feedback.
   - **blank** (black/white flash, from the blackdetect/whiteout rules).
6. **Jank during transitions:** within animated transitions, use PTS intervals and unique-frame cadence (cportka `--stutter`: freezedetect + mpdecimate + showinfo in one pass, freeze-min 0.1 s; raise it to 0.2 to mute VFR noise). Report the longest freeze gaps. Only valid if the recording fps is high enough (≥ 50); otherwise say "cannot assess smoothness at 30 fps".
7. **Layout shift without input:** large-area translation of existing content after t_settle-like quiescence and with no new input. Detect it as a large changed fraction with a near-identical shifted image; check by comparing a frame with its vertically shifted predecessor. Report it as a CLS-like finding and verify on the before/after strip.
8. **Thresholds to grade by** (cite RAIL / Nielsen, and video-ux-audit's P1 rule):
   - Acknowledgement (feedback) ≤ 100 ms is good; over 100 ms is a P2 "feels laggy" (MobileGUIPerf alert threshold).
   - Response under 100 ms feels instant; 100–1000 ms needs a visible state change; over 1 s with no progress indicator is P1; over 1 s with a spinner is P2.
   - Settle (finish): over 1 s for an action, or over 3 s for a view/screen load, is P1 (video-ux-audit).
   - A frozen gap of 250 ms or more after input with no feedback is a finding.
   - A transition animation over ~500 ms is a "slow animation" design note.
   - Always print the measurement resolution (±1 frame interval) and the input-detection method next to each number. MobileGUIPerf's honest numbers: RT MAE ~33 ms, FT MAE ~200 ms even with a 60 fps capture and a show-taps marker.
9. **Evidence per latency finding:**
   - a filmstrip (cells at t_in−1 frame, t_in, t_first, a mid-wait frame, t_settle, labelled with ms offsets from t_in such as "+0 ms / +180 ms / +1240 ms");
   - the changed-fraction sparkline for the window, written as a CSV for the report and optionally rendered as a PNG;
   - Claude confirms on the filmstrip that t_first is a real response and not an indicator, highlight, cursor blink or caret blink. Caret and cursor blink is a classic false positive (500 ms period, tiny area), so mask a blinking caret region if detected.

### 9.7 Design/UI review pass (Claude, on frames)
- Feed the flow-overview grids plus a small number of full-resolution detail frames (one per distinct screen) with a structured prompt, adapted from video-ux-audit:
  - Persona: senior UX + visual design + performance reviewer.
  - Per distinct screen: layout and alignment, spacing rhythm, type hierarchy and legibility, contrast (approximate only; compression shifts colour, per cportka), truncation/clipping/overflow at edges (`--edge` crop), inconsistent components across screens, touch target size as % of viewport width (~44 pt ≈ 11–12% of an iPhone portrait width), safe-area/notch collisions, keyboard covering inputs, empty/loading/error states.
  - Per transition: missing feedback, dead ends, two surfaces disagreeing after an action, content flashes, half-rendered states, A→B→A reverts (cportka `--content-revert`).
  - Output rows: ID, severity (P0/P1/P2), category (UI bug / design / latency), title, expected, actual, video time (ms), evidence (grid#cell or frame file + measured numbers), confidence (measured / seen / inferred), suggested fix.
  - Rules: "no evidence, no row"; quote exact on-screen text; label seen vs inferred; treat causal stories as hypotheses (ii23); state what frames cannot show (continuous easing, sub-frame timing, off-screen state, exact colours).
- Verify every auto-signal against its frames before promoting it to a finding, and keep a "signals dismissed as noise" appendix (video-ux-audit's 61%-real lesson).

### 9.8 Token budgeting
- **Formula:** tokens ≈ (w × h) / 750 after the downscale to ≤ 1568 px long edge (≈ 1.15 MP cap), so a maxed image costs about 1.5–1.9k tokens (ii23 measured ~1.85–1.9k for a 1568-edge grid).
- **Per-image costs:**
  - Phone portrait single at 724×1568 ≈ 1.5k tokens.
  - Desktop single at 1568×980 ≈ 2.0k (the cap applies).
  - A 512 px-wide 16:9 frame ≈ 0.4k but is illegible for UI text, so don't use it for review.
- **Default budget for a 30–90 s UI recording:**
  - 1–3 overview grids (≈ 2k each);
  - 8–20 detail frames (≈ 1.5–2k each);
  - ≈ 2 filmstrips per latency finding (≈ 2k each).
  - Target 40–80k image tokens. Scale by distinct-state count, not duration (ii23: budget frames, not fps; thin evenly, never truncate the tail, report thinning).
- **Duration tiers** for overview candidates (guimatheus): 12 / 20 / 30 / 45 / 60 frames for ≤ 30 s / ≤ 60 s / ≤ 3 min / ≤ 10 min / longer. Detail frames come from distinct states, capped at ~24.
- **Text first:** the change timeline, the event list (t_in, t_first, t_settle, classification) and the manifest go into context as compact text (cheap), so Claude decides which frames to look at (claude-video-vision's "analyse before extract" and "binary search" rule).
- **Extract to disk freely; Read selectively.** Cache by file hash plus ms timestamp + resolution, so follow-ups never re-read.
- **Prefer grids for overview** (7× cheaper per frame) and singles only for text/design detail. Never put 16+ cells of phone UI in one grid when text matters.
- For recordings over 3 minutes, ask the user to trim or give a focus window (stoneberg: under 3 min works best; danielthegoldman: narrow the range first).

### 9.9 Portability pitfalls to bake in
- `-fps_mode` vs `-vsync` (ffmpeg 5.1+).
- `-ss` before `-i` resets timestamps, so use `-t`, not `-to`, or add the offset back.
- drawtext may be missing (Homebrew without freetype): probe it and fall back to bitmap labels.
- Overlay re-init on size change truncates grids, so keep label widths equal.
- Rotation metadata on phone videos: measure the extracted frame, not the stream.
- HDR/10-bit HEVC from iPhone: add `format=yuv420p` (and `zscale` tonemap if available) before jpeg output, or colours wash out.
- VFR 240 timebase on macOS; Android screenrecord emits only on change.
- mpdecimate positional args shifted in newer ffmpeg, so use named options.
- macOS bash 3.2 has no mapfile; prefer Python stdlib scripts (ii23's choice) over huge bash scripts (cportka's 178 KB script is a maintenance warning).
- Analysis timeouts: report `analyzed_until` rather than silently truncating (claude-video-vision).
- Never install ffmpeg silently; detect it and tell the user (cportka).
