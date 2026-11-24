#!/usr/bin/env python3
"""Recolours Sakuga VFX's painted toggle (MIT, Justin Finkelman) for Purrperty.

    sakuga_toggle.py <toggle/frames.webp> <out.png>

Violet becomes cherry, pink becomes gold, the navy ink warm brown, and the
painted lettering comes off (the app draws its own).
"""
import sys
from collections import deque

import numpy as np
from PIL import Image

CW, CH, COUNT, COLS = 300, 325, 43, 8
im = np.asarray(Image.open(sys.argv[1]).convert("RGBA")).astype(float) / 255
rgb, a = im[..., :3], im[..., 3]
mx, mn = rgb.max(-1), rgb.min(-1)
d = mx - mn
sat = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
hue = np.select([mx == r, mx == g], [((g - b) / np.maximum(d, 1e-6)) % 6, (b - r) / np.maximum(d, 1e-6) + 2], (r - g) / np.maximum(d, 1e-6) + 4) * 60

pink = (sat > 0.35) & (mx > 0.55) & ((hue > 300) | (hue < 5))
alpha = a.copy()
for f in range(COUNT):
    y0, x0 = (f // COLS) * CH, (f % COLS) * CW
    solid = a[y0:y0 + CH, x0:x0 + CW] > 0.15
    hot = pink[y0:y0 + CH, x0:x0 + CW]
    seen = np.zeros_like(solid)
    for sy, sx in zip(*np.nonzero(hot & solid)):
        if seen[sy, sx] or sy > 112:
            continue
        queue, part = deque([(sy, sx)]), []
        seen[sy, sx] = True
        while queue:
            y, x = queue.popleft()
            part.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < CH and 0 <= nx < CW and solid[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
        # Letters live at the top; the wedges and the glint don't.
        if f < 40 and max(y for y, _ in part) < 125:
            for y, x in part:
                alpha[y0 + y, x0 + x] = 0


def hsv(h, s, v):
    h = (h % 360) / 60
    i = np.floor(h).astype(int) % 6
    q = h - np.floor(h)
    p_, q_, t_ = v * (1 - s), v * (1 - s * q), v * (1 - s * (1 - q))
    return np.stack([np.choose(i, [v, q_, p_, p_, t_, v]), np.choose(i, [t_, v, v, q_, p_, p_]), np.choose(i, [p_, p_, t_, v, v, q_])], -1)


cool = (hue > 190) & (hue < 290) & (sat > 0.04)
h2, s2, v2 = hue.copy(), sat.copy(), mx.copy()
ink = cool & (mx < 0.45)
h2 = np.where(cool, 4, h2)
s2 = np.where(cool & ~ink, np.minimum(1, sat * 1.45), s2)
v2 = np.where(cool & ~ink, np.minimum(1, mx * 0.96), v2)
h2 = np.where(ink, 12, h2); s2 = np.where(ink, 0.58, s2); v2 = np.where(ink, mx * 0.55, v2)
h2 = np.where(pink, 41, h2); s2 = np.where(pink, 0.76, s2); v2 = np.where(pink, 0.95, v2)
out = np.dstack([hsv(h2, s2, v2), alpha])
Image.fromarray((out * 255).round().astype("uint8")).save(sys.argv[2], optimize=True)
