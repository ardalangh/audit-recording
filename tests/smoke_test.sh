#!/usr/bin/env bash
# Smoke test: build a synthetic "app" recording with ffmpeg, run every script command on it,
# render a report from a minimal findings.json, and check that the expected files exist.
# Needs: bash, python3 (3.9+), ffmpeg, ffprobe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/audit-recording"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== frontmatter"
python3 "$ROOT/tests/check_frontmatter.py" "$SKILL/SKILL.md"

echo "== synthetic recording"
# 390x844 phone-sized screen, 30 fps, 4 s:
#   t=1.5 s a blue "button response" bar appears (local change),
#   t=2.5 s the whole screen turns grey (navigation).
ffmpeg -v error -y \
  -f lavfi -i "color=c=white:s=390x844:r=30:d=4" \
  -f lavfi -i "color=c=0x3355ff:s=300x60:r=30:d=4" \
  -f lavfi -i "color=c=0xdddddd:s=390x844:r=30:d=4" \
  -filter_complex "[0][1]overlay=45:600:enable='gte(t,1.5)'[a];[a][2]overlay=0:0:enable='gte(t,2.5)'" \
  -c:v libx264 -pix_fmt yuv420p "$WORK/demo.mp4"

OUT="$WORK/audit"
echo "== analyze"
python3 "$SKILL/scripts/rec_audit.py" analyze "$WORK/demo.mp4" --out "$OUT" --platform ios
echo "== measure"
python3 "$SKILL/scripts/rec_audit.py" measure "$OUT" --input 1.0 --until 2.4 --label "Tap button"
echo "== strip"
python3 "$SKILL/scripts/rec_audit.py" strip "$OUT" --from 1.2 --to 2.0 --cells 6
echo "== frames"
python3 "$SKILL/scripts/rec_audit.py" frames "$OUT" --at 0.5,1.6 --crop 0,560,390,140

for f in analysis.md analysis.json measurements.md; do
  [ -s "$OUT/$f" ] || { echo "missing $f"; exit 1; }
done
grep -q "1.5" "$OUT/analysis.md" || { echo "analysis.md does not mention the 1.5 s change"; exit 1; }

echo "== render report"
cat > "$OUT/findings.json" <<'JSON'
{
  "title": "Smoke Test Flow",
  "subject": "Synthetic recording used by the test suite.",
  "summary": "One finding, to exercise the renderer.",
  "top_fixes": ["Show feedback sooner"],
  "timeline": [{"time": 0.0, "screen": "Start", "change": "White screen"}],
  "findings": [{
    "id": "F-01", "severity": "P3", "confidence": "Low", "title": "Button feedback arrives after 500 ms",
    "check": "LAT-FEEDBACK", "screen": "Start", "time": "00:01.0-00:01.5",
    "evidence": [{"time": 1.6, "caption": "The bar appears", "marks": [{"x": 45, "y": 600, "w": 300, "h": 60, "label": "1"}]}],
    "observation": "The bar appears 500 ms after the input.", "expected": "Feedback within 100 ms.",
    "impact": "The tap feels ignored.",
    "fix": {"summary": "Show a pressed state immediately.",
            "mock": {"caption": "Pressed state.", "css": ".b{background:#35f;color:#fff;padding:12px;border-radius:8px}",
                     "html": "<div class=\"b chg\">Pressed</div>"},
            "changes": [{"what": "Pressed state", "before": "none", "after": "darken 10%"}],
            "effort": "S", "verify": "Re-record and measure."}
  }],
  "positives": [], "evidence_limits": [], "not_assessable": [], "dismissed": [], "next_checks": []
}
JSON
python3 "$SKILL/scripts/render_report.py" "$OUT"
[ -s "$OUT/report/index.html" ] || { echo "missing report/index.html"; exit 1; }
[ -s "$OUT/report/report.md" ] || { echo "missing report/report.md"; exit 1; }
ls "$OUT/report/img/"*.jpg >/dev/null || { echo "missing report images"; exit 1; }
grep -q "shadowrootmode" "$OUT/report/index.html" || { echo "mock not rendered"; exit 1; }

echo "OK: all smoke checks passed"
