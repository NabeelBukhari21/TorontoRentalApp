#!/usr/bin/env python3
"""Prepare a mascot clip for the app.

Generated clips arrive on an off-white (~#F8F8F8), slightly noisy
background. The app shows clips on a pure-white card, so this pushes
near-white, low-chroma pixels to #FFFFFF (the cat's own white fur is
warmer and keeps its shading), drops the audio track, and encodes a
small H.264 file with fast start.

    python3 tools/mascot/video_whiten.py IN.mp4 OUT.mp4

Requires ffmpeg, NumPy and Pillow.
"""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)

def whiten(frame):
    a = np.asarray(frame.convert("RGB")).astype(np.float32)
    lum = a.mean(-1)
    chroma = a.max(-1) - a.min(-1)
    w = smoothstep(236, 246, lum) * (1 - smoothstep(6, 12, chroma))
    out = a + (255 - a) * w[..., None]
    return Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8))

def main(src, dst, fps="24"):
    with tempfile.TemporaryDirectory() as tmp:
        raw, clean = os.path.join(tmp, "raw"), os.path.join(tmp, "clean")
        os.makedirs(raw); os.makedirs(clean)
        subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-an",
                        os.path.join(raw, "%04d.png")], check=True)
        for name in sorted(os.listdir(raw)):
            whiten(Image.open(os.path.join(raw, name))).save(os.path.join(clean, name))
        subprocess.run([
            "ffmpeg", "-v", "error", "-y", "-framerate", fps,
            "-i", os.path.join(clean, "%04d.png"),
            "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-tune", "animation",
            "-pix_fmt", "yuv420p", "-vf", "scale=out_color_matrix=bt709:out_range=tv",
            "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
            "-movflags", "+faststart", "-an", dst], check=True)

if __name__ == "__main__":
    main(*sys.argv[1:3])
