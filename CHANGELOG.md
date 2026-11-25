# Changelog

All notable changes are listed here. Versions follow [Semantic Versioning](https://semver.org/);
the version lives in `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` and the
`metadata.version` field of `skills/audit-recording/SKILL.md`. Bump all three together.

## 1.0.0 - 2026-11-25

First public release.

- `rec_audit.py analyze`: timing from real frame timestamps (works on variable-frame-rate recordings),
  change bursts with size and location, auto-signals (hitch, blank, flash, revert, repeating, spinner,
  long change), overview grids, full-resolution state frames and zoomed event filmstrips.
- `rec_audit.py measure`: input-to-feedback, response, settle time, frozen waits and spinners for one action.
- `rec_audit.py strip` / `frames`: labelled frames by decoded index, with optional crop and zoom.
- `render_report.py`: findings.json to a self-contained page with circled problems, zoomed close-ups and
  HTML/CSS mock-ups of each fix, plus a Markdown version.
- A code pass: when the app's source is in the workspace, mock-ups use its real tokens, fonts and copy,
  findings are checked against the code, and each fix lists file and line.
- References: latency thresholds, a UI/design/motion checklist with about 120 check IDs, platform norms
  for iOS, Android, web, macOS, Windows and Electron, and the report format.
