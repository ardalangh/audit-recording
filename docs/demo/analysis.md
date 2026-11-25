# Recording analysis: demo.mp4

Output folder: `recording-audits/demo`
Focus: Saving the profile; why it feels slow

## Recording
- 780x1688 displayed (stored 780x1688), h264, 7.60 s, 228 frames decoded. Platform guess from shape: **ios** (confirm with the user).
- Frame intervals: median 33.3 ms, during motion 33.3 ms (~30 fps), p95 33.3 ms, max 33 ms. Nominal rate 30/1 is a timebase, not the real rate.
- **Timing resolution: about ±33 ms** (one frame during motion). 
- Change detection: pixel changes > 24/255 at 1600 px long edge on a 27x48 cell grid; noise floor 0.02% of the screen.

## Activity timeline
Each row is a burst of visual change. `start` is the first frame showing the change, `end` the last changed frame (the new state). Kind: screen (most of the screen), region (a panel or section), local (a small area: button, toast, spinner), tiny (a few characters, an icon, the cursor or caret). Tiny is not unimportant: typed text and label changes are tiny.

| ID | start | end | dur ms | kind | peak | where: separate changed areas (px x,y,w,h) | frames | longest gap ms |
|---|---|---|---|---|---|---|---|---|
| E01 | 00:01.000 | 00:01.133 | 133 | local | 0.16% | bottom-center (317, 1477, 115, 140) | 2 | 33 |
| E02 | 00:02.533 | 00:02.533 | 0 | local | 1.97% | bottom-center (231, 1371, 317, 105) | 1 | 0 |
| E03 | 00:04.133 | 00:04.133 | 0 | local | 1.97% | bottom-center (231, 1371, 317, 105) | 1 | 0 |
| E04 | 00:04.633 | 00:04.633 | 0 | region | 9.41% | bottom-center (28, 1477, 722, 140); middle-center (57, 492, 577, 422); top-center (288, 211, 202, 246); middle-center (57, 949, 548, 70) | 1 | 0 |

## Auto-signals (hypotheses: verify each on frames before reporting; expect ~40% noise)
- none

## Candidate input moments
Input times are not in the video unless touches/clicks are shown. Confirm or correct each on its event strip, then run `measure` with the input time.
- small change at 00:01.000 (bottom-center) 1533 ms before E02: possible press / hover / cursor feedback
- small change at 00:04.133 (bottom-center) 500 ms before E04: possible press / hover / cursor feedback

## Images to review
Overview grids (one cell per distinct visual state, labels show state id and time):
- `grids/overview_01.jpg`: S01, S02, S03, S04

Full-resolution state frames (use these for text, spacing, alignment, contrast):
- S01 00:00.000 `states/S01_00-00.000.jpg` (start, after E01)
- S02 00:02.533 `states/S02_00-02.533.jpg` (after E02)
- S03 00:04.133 `states/S03_00-04.133.jpg` (after E03)
- S04 00:04.633 `states/S04_00-04.633.jpg` (after E04)

Event filmstrips (frame before, first change, middle, last change, +500 ms; labels show +ms from the first change):
- `events/E02_00-02.533.jpg` (zoomed to x,y,w,h (134, 586, 508, 1100))
- `events/E03_00-04.133.jpg` (zoomed to x,y,w,h (134, 586, 508, 1100))
- `events/E04_00-04.633.jpg`

