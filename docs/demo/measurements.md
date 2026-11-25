### Tap Save
- Input: 00:01.000 (frame on screen 00:01.000), found by: show-touches dot. Resolution about ±33 ms; every number below is measured from the input frame.
- Changes after the input (each row is one distinct change):

  | # | starts | ends | peak | changed areas (px x,y,w,h) |
  |---|---|---|---|---|
  | 1 | +1533 ms | +1533 ms | 1.99% | bottom-center (231, 1371, 317, 105) |
  | 2 | +3133 ms | +3133 ms | 1.99% | bottom-center (231, 1371, 317, 105) |

- First visible change: +1533 ms [POOR vs 100 / 250 ms]. Small: likely pressed state, hover, cursor or caret; confirm on the strip.
- No substantial change (>= 3%% of screen or a >= 8%% area) in the window: the result may be small (toast, label, counter) or missing. Check the strip.
- Visually settled: +1533 ms at 00:02.533 (then 500 ms or more without change) [needs work vs 1 s action / 3 s view]
- Nothing changed from 00:01.000 to 00:02.533 (1533 ms) while waiting for the result: no feedback during this wait.
- Ignored regions are excluded. A recorder that skips unchanged frames can hide short changes; confirm every number on the strip.
- Strip: `measure/M_00-01.000.jpg`

