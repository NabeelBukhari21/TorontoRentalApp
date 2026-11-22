"""Render Purr's moods as transparent PNG stills, from the app itself.

The rive CLI can't render this project here, so the app does it: a DEBUG
launch argument (`-PurrpertyStill <mood>`, see PurrStillStudio.swift) shows
one mood full width, freezes it, and switches the background from white to
black. Two simulator screenshots of the same frozen frame give exact alpha:

    alpha = 1 - (white - black) / 255,  colour = black / alpha

    python3 purr_stills.py --udid <booted simulator> --out out/stills welcome success error

Needs Pillow and NumPy, a booted simulator with the Debug build installed.
"""

import argparse
import os
import subprocess
import time

import numpy as np
from PIL import Image

BUNDLE = "Seneca.Syed.RentalApp"


def shoot(udid: str, path: str) -> None:
    subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", path], check=True, capture_output=True)


def matte(white_path: str, black_path: str) -> Image.Image:
    white = np.asarray(Image.open(white_path).convert("RGB"), dtype=np.float32)
    black = np.asarray(Image.open(black_path).convert("RGB"), dtype=np.float32)
    alpha = 1 - (white - black).mean(axis=2) / 255
    alpha = np.clip(alpha, 0, 1)
    safe = np.maximum(alpha, 1e-4)[..., None]
    colour = np.clip(black / safe, 0, 255)
    rgba = np.dstack([colour, alpha * 255]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def render(udid: str, mood: str, style: str, out: str) -> str:
    subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE], capture_output=True)
    subprocess.run(["xcrun", "simctl", "launch", udid, BUNDLE,
                    "-PurrpertyStill", mood, "-PurrpertyStillStyle", style],
                   check=True, capture_output=True)
    start = time.time()
    white, black = f"{out}/.{mood}_w.png", f"{out}/.{mood}_b.png"
    time.sleep(max(0, 2.4 - (time.time() - start)))
    shoot(udid, white)
    time.sleep(max(0, 3.8 - (time.time() - start)))
    shoot(udid, black)
    image = matte(white, black)
    # Purr's canvas is a square the width of the screen, centred.
    w, h = image.size
    top = (h - w) // 2
    image = image.crop((0, top, w, top + w))
    path = f"{out}/{style}_{mood}.png"
    image.save(path, optimize=True)
    os.remove(white)
    os.remove(black)
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--style", default="classic")
    parser.add_argument("--out", default="out/stills")
    parser.add_argument("moods", nargs="+")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for mood in args.moods:
        print(render(args.udid, mood, args.style, args.out))


if __name__ == "__main__":
    main()
