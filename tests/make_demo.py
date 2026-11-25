#!/usr/bin/env python3
"""Write a deterministic synthetic app recording (raw frames piped to ffmpeg).

390x844 at 30 fps for 4 s: white screen; at 1.5 s a blue bar appears at (45, 600, 300x60);
at 2.5 s the whole screen turns grey. Frames are built here, not with ffmpeg filters, so every
ffmpeg version encodes the same pictures.
"""
import subprocess
import sys

W, H, FPS, SECONDS = 390, 844, 30, 4
WHITE, BLUE, GREY = b"\xff\xff\xff", b"\x33\x55\xff", b"\xdd\xdd\xdd"


def frame(bar, grey):
    if grey:
        return GREY * (W * H)
    row = WHITE * W
    bar_row = WHITE * 45 + BLUE * 300 + WHITE * (W - 345)
    rows = [bar_row if bar and 600 <= y < 660 else row for y in range(H)]
    return b"".join(rows)


def main(out):
    plain, with_bar, grey = frame(False, False), frame(True, False), frame(False, True)
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", out]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for i in range(FPS * SECONDS):
        t = i / FPS
        proc.stdin.write(grey if t >= 2.5 else with_bar if t >= 1.5 else plain)
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed")


if __name__ == "__main__":
    main(sys.argv[1])
