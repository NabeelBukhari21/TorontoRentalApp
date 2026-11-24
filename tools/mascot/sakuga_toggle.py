#!/usr/bin/env python3
"""Recolours Sakuga VFX's painted toggle (MIT, Justin Finkelman) for Purrperty.

    sakuga_toggle.py <toggle/frames.webp> <out.png>

Violet becomes cherry, pink becomes gold, the navy ink warm brown, and the
painted lettering comes off (the app draws its own). Then it's made
steady: the painted switch shrinks as it plays (108, 98, 84 px tall), its
colour pops in one frame and its glint never leaves. Here every frame is
the same size, the colour floods in, the settled frames are redrawn, a paw
rides on the knob, and five extra frames drain the colour for turning off.
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
sheet = Image.fromarray((out * 255).round().astype("uint8"))

# ── Steady ──
from PIL import ImageDraw, ImageFilter

HEIGHT, MID, LEFT, RIGHT = 104, 230.5, 44, 256     # the switch, in a cell
OFF, ON = np.array([201, 172, 168]), np.array([228, 74, 66])
INK, PAPER, SHADE, DEEP, CHERRY = (43, 23, 18), (255, 253, 248), (244, 132, 120), (190, 38, 38), (204, 46, 46)
SS = 4


def paw(size, colour):
    """A paw print on clear, `size` px across."""
    n = size * SS
    im_ = Image.new("RGBA", (n, n))
    d_ = ImageDraw.Draw(im_)
    d_.ellipse((n * .24, n * .46, n * .76, n * .92), fill=colour)
    d_.ellipse((n * .16, n * .62, n * .46, n * .93), fill=colour)
    d_.ellipse((n * .54, n * .62, n * .84, n * .93), fill=colour)
    for x, y, w, h in ((.01, .34, .22, .28), (.23, .09, .23, .33), (.54, .09, .23, .33), (.77, .34, .22, .28)):
        d_.ellipse((n * x, n * y, n * (x + w), n * (y + h)), fill=colour)
    return im_.resize((size, size), Image.LANCZOS)


def redraw(track, level=0.0, phase=0.0, squash=0.0, bubbles=()):
    """A settled frame: the track in `track`, with liquid to `level`."""
    im_ = Image.new("RGBA", (CW * SS, CH * SS))
    d_ = ImageDraw.Draw(im_)
    top, bot = MID - HEIGHT / 2 + squash, MID + HEIGHT / 2 - squash
    box = [v * SS for v in (LEFT, top, RIGHT, bot)]
    r_ = (bot - top) / 2 * SS
    inner = Image.new("L", im_.size)
    ImageDraw.Draw(inner).rounded_rectangle(box, r_, fill=255)
    d_.rounded_rectangle(box, r_, fill=tuple(int(v) for v in track) + (255,))
    if level > 0.01:
        def wave(colour, drop, amp, ph):
            lay = Image.new("RGBA", im_.size)
            y0 = bot - (bot - top) * level + drop
            pts = [(x * SS, (y0 + amp * (np.sin(x / 15 + ph) + .5 * np.sin(x / 7 - ph * 1.3))) * SS) for x in range(LEFT, RIGHT + 1, 2)]
            ImageDraw.Draw(lay).polygon(pts + [(RIGHT * SS, bot * SS), (LEFT * SS, bot * SS)], fill=colour)
            im_.paste(lay, (0, 0), Image.composite(lay.getchannel("A"), Image.new("L", im_.size), inner))
        amp = 1 + 5 * level
        wave(PAPER + (255,), 0, amp, phase)
        wave((240, 108, 98, 255), 7, amp * .8, phase + .5)
        wave(DEEP + (255,), 17, amp * .6, phase + 1.2)
    for x, y, rr in bubbles:
        d_.ellipse([v * SS for v in (x - rr, y - rr, x + rr, y + rr)], fill=PAPER, outline=INK, width=2 * SS)
    d_.rounded_rectangle(box, r_, outline=INK, width=7 * SS)
    cx, cy, kr = 208, MID, 47 - squash
    knob = [v * SS for v in (cx - kr, cy - kr, cx + kr, cy + kr)]
    d_.ellipse(knob, fill=SHADE)
    light = Image.new("L", im_.size)
    ImageDraw.Draw(light).ellipse([v * SS for v in (cx - kr - 9, cy - kr - 11, cx + kr - 9, cy + kr - 11)], fill=255)
    mask = Image.new("L", im_.size)
    ImageDraw.Draw(mask).ellipse(knob, fill=255)
    im_.paste(Image.new("RGBA", im_.size, PAPER + (255,)), (0, 0), Image.composite(light, Image.new("L", im_.size), mask))
    d_.ellipse(knob, outline=INK, width=6 * SS)
    return im_.resize((CW, CH), Image.LANCZOS)


def stamp(cell, cx, size=46, colour=CHERRY + (255,)):
    cell.alpha_composite(paw(size, colour), (int(cx - size / 2), int(MID - size / 2)))


final = Image.new("RGBA", (CW * COLS, CH * 6))
for f in range(48):
    if f < 29:
        cell = sheet.crop(((f % COLS) * CW, (f // COLS) * CH, (f % COLS + 1) * CW, (f // COLS + 1) * CH))
        # The same height throughout, about the middle.
        h = 108 if f < 13 else 98
        k = HEIGHT / h
        mid = 230.5 if f < 13 else 231.0
        cell = cell.transform((CW, CH), Image.AFFINE, (1, 0, 0, 0, 1 / k, mid - MID / k), Image.BICUBIC)
        # The track's colour floods in, ahead of the settled frames.
        flood = max(0.0, min(1.0, (f - 14) / 14))
        if flood:
            px = np.asarray(cell).astype(float)
            c_ = px[..., :3]
            yy, xx = np.mgrid[0:CH, 0:CW]
            # From where the splash landed, outward.
            reach = np.clip((flood * 1.5 - np.abs(xx - 190) / 300) * 2, 0, 1)
            near = np.abs(c_ - np.array([199, 172, 169])).max(-1) < 26
            a_ = (near & (px[..., 3] > 200)) * reach
            px[..., :3] = c_ * (1 - a_[..., None]) + ON * a_[..., None]
            cell = Image.fromarray(px.round().astype("uint8"))
        if f < 5:
            stamp(cell, 97, colour=(233, 150, 140, 255))
        elif f >= 13:
            stamp(cell, 208)
    elif f < 43:
        # Settling: the liquid drops and the switch springs.
        t_ = (f - 29) / 13
        squash = 3.2 * np.exp(-t_ * 4) * np.cos(t_ * 16)
        fall = [(112 + 26 * i, 214 - 30 * i + t_ * 130, 4 - i * .6) for i in range(2) if 214 - 30 * i + t_ * 130 < 268]
        cell = redraw(ON, level=.42 * (1 - t_) ** 1.5, phase=f * .55, squash=squash, bubbles=fall if t_ < .5 else ())
        stamp(cell, 208)
    else:
        # Turning off: the colour drains before the knob goes.
        t_ = (f - 42) / 5
        cell = redraw(ON * (1 - t_) + OFF * t_, squash=2.5 * np.sin(t_ * np.pi))
        stamp(cell, 208, colour=tuple(int(v) for v in np.array(CHERRY) * (1 - t_) + np.array([233, 150, 140]) * t_) + (255,))
    final.paste(cell, ((f % COLS) * CW, (f // COLS) * CH))

final.quantize(256, Image.Quantize.FASTOCTREE).save(sys.argv[2], optimize=True)
