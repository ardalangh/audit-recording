#!/usr/bin/env bash
# Rebuild docs/demo/recording.mp4 from the demo app: screenshot each state with headless Chrome,
# then lay the screenshots out on a timeline with ffmpeg (30 fps, 780x1688, like an iPhone recording).
# Timeline: tap Save at 1.0 s (show-touches dot), no change for 1.4 s, toast at 2.53 s, Settings at 4.63 s.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
for s in form tap saved settings; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=390,844 \
    --force-device-scale-factor=2 --user-data-dir="$WORK/chrome" \
    --screenshot="$WORK/$s.png" "file://$HERE/app/index.html?s=$s" >/dev/null 2>&1
done
cat > "$WORK/list.txt" <<LIST
file 'form.png'
duration 1.0
file 'tap.png'
duration 0.1333
file 'form.png'
duration 1.4
file 'saved.png'
duration 1.6
file 'form.png'
duration 0.5
file 'settings.png'
duration 1.5
file 'settings.png'
LIST
(cd "$WORK" && ffmpeg -v error -y -f concat -i list.txt -vf "fps=30,format=yuv420p" -c:v libx264 -crf 20 \
  -movflags +faststart "$HERE/recording.mp4")
echo "wrote $HERE/recording.mp4"
