"""Purrperty's app icon and logo art, built from Purr stills.

Composes layered artwork for Icon Composer (`AppIcon.icon`): each layer is
a full 1024×1024 PNG so positions are exact, and each group gets Liquid
Glass in iOS 26. Then `ictool` renders every appearance for review.

    python3 logo_icon.py --stills out/stills --out out/logo [A B]

Directions:
  A  "Peek-a-roof"  Purr peeks over a glossy cherry roof on a cream tile.
  B  "Key bubble"   Purr with his gold house key in a cream glass bubble
                    on a cherry tile.

Needs Pillow and NumPy; Purr stills from purr_stills.py.
"""

import argparse
import json
import os
import shutil
import subprocess

from PIL import Image, ImageDraw

S = 1024
SS = 4  # supersampling for drawn shapes
ICTOOL = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
RENDITIONS = ["Default", "Dark", "ClearLight", "ClearDark", "TintedLight", "TintedDark"]

CHERRY = (224, 56, 56)
CHERRY_DEEP = (176, 39, 39)
EMBER = (180, 80, 30)
GOLD = (242, 184, 58)
GOLD_LIGHT = (255, 214, 122)
CREAM = (255, 244, 228)
INK = (56, 24, 16)


def canvas():
    return Image.new("RGBA", (S * SS, S * SS), (0, 0, 0, 0))


def finish(img):
    return img.resize((S, S), Image.LANCZOS)


def place(still_path, scale, dx, dy):
    """A Purr still on a transparent 1024 canvas, scaled and offset."""
    cat = Image.open(still_path).convert("RGBA")
    size = int(cat.width * scale)
    cat = cat.resize((size, size), Image.LANCZOS)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.alpha_composite(cat, (int((S - size) / 2 + dx), int(dy)))
    return layer


def srgb(c, a=1.0):
    return "srgb:" + ",".join(f"{v / 255:.5f}" for v in c) + f",{a:.5f}"


def write_icon(path, fill, groups, dark_fill=None):
    """`groups` is front to back: [(layer_name, glass, translucency), ...]."""
    doc = {
        "fill": fill,
        "groups": [
            {
                "layers": [{"image-name": f"{name}.png", "name": name, "glass": glass}],
                "shadow": {"kind": "neutral", "opacity": 0.5},
                "translucency": {"enabled": translucency > 0, "value": translucency},
                "specular": glass,
            }
            for name, glass, translucency in groups
        ],
        "supported-platforms": {"squares": "shared"},
    }
    if dark_fill:
        doc["fill-specializations"] = [{"value": fill}, {"appearance": "dark", "value": dark_fill}]
    with open(os.path.join(path, "icon.json"), "w") as f:
        json.dump(doc, f, indent=2)


# MARK: - A: Peek-a-roof

def roof_layer():
    img = canvas()
    d = ImageDraw.Draw(img)
    k = SS
    # Cream wall with a little door, under the eaves.
    d.rounded_rectangle((170 * k, 860 * k, 854 * k, 1100 * k), radius=40 * k, fill=CREAM + (255,))
    d.rounded_rectangle((452 * k, 905 * k, 572 * k, 1100 * k), radius=60 * k, fill=CHERRY_DEEP + (255,))
    d.ellipse((540 * k, 990 * k, 556 * k, 1006 * k), fill=GOLD + (255,))
    # The roof: a wide, chunky trapezoid with rounded ends.
    top, eave = 715, 885
    d.rounded_rectangle((150 * k, top * k, 874 * k, (top + 60) * k), radius=30 * k, fill=CHERRY + (255,))
    d.polygon([(150 * k, (top + 30) * k), (874 * k, (top + 30) * k), (1010 * k, eave * k), (14 * k, eave * k)], fill=CHERRY + (255,))
    d.rounded_rectangle((-10 * k, (eave - 52) * k, 1034 * k, (eave + 8) * k), radius=30 * k, fill=CHERRY_DEEP + (255,))
    # Roof tiles: two soft rows of scallops.
    for row, y in enumerate((770, 820)):
        x = 120 + row * 40
        while x < 930:
            d.ellipse(((x - 34) * k, (y - 20) * k, (x + 34) * k, (y + 20) * k), fill=(236, 84, 74, 255))
            x += 80
    # A gold ridge cap along the top, like the tag on Purr's collar.
    d.rounded_rectangle((150 * k, (top - 6) * k, 874 * k, (top + 22) * k), radius=14 * k, fill=GOLD + (255,))
    return finish(img)


def option_a(stills, out):
    path = os.path.join(out, "A", "AppIcon.icon")
    shutil.rmtree(os.path.dirname(path), ignore_errors=True)
    os.makedirs(os.path.join(path, "Assets"))
    purr = place(os.path.join(stills, "classic_dashboard.png"), 1.02, -18, -175)
    purr.save(os.path.join(path, "Assets", "Purr.png"))
    roof_layer().save(os.path.join(path, "Assets", "Roof.png"))
    fill = {"linear-gradient": [srgb(CREAM), srgb(GOLD_LIGHT)]}
    dark = {"linear-gradient": [srgb((58, 34, 28)), srgb((30, 20, 18))]}
    write_icon(path, fill, [("Roof", True, 0.0), ("Purr", True, 0.0)], dark)
    return path


# MARK: - B: Key bubble

def bubble_layer():
    img = canvas()
    d = ImageDraw.Draw(img)
    k = SS
    cx, cy, r = 512, 532, 372
    d.ellipse(((cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k), fill=CREAM + (255,))
    return finish(img)


def option_b(stills, out):
    path = os.path.join(out, "B", "AppIcon.icon")
    shutil.rmtree(os.path.dirname(path), ignore_errors=True)
    os.makedirs(os.path.join(path, "Assets"))
    place(os.path.join(stills, "classic_login.png"), 0.76, 12, 48).save(os.path.join(path, "Assets", "Purr.png"))
    bubble_layer().save(os.path.join(path, "Assets", "Bubble.png"))
    fill = {"linear-gradient": [srgb(CHERRY), srgb(EMBER)]}
    dark = {"linear-gradient": [srgb((120, 28, 28)), srgb((50, 18, 14))]}
    write_icon(path, fill, [("Purr", True, 0.0), ("Bubble", True, 0.3)], dark)
    return path


# MARK: - Renders

def render(icon_path, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for r in RENDITIONS:
        args = [ICTOOL, icon_path, "--export-image", "--output-file", os.path.join(out_dir, f"{r}.png"),
                "--platform", "iOS", "--rendition", r, "--width", "1024", "--height", "1024", "--scale", "1"]
        if r.startswith("Tinted"):
            args += ["--tint-color", "0.02", "--tint-strength", "0.75"]
        subprocess.run(args, check=True, capture_output=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--stills", default="out/stills")
    parser.add_argument("--out", default="out/logo")
    parser.add_argument("options", nargs="*", default=["A", "B"])
    args = parser.parse_args()
    builders = {"A": option_a, "B": option_b}
    for option in args.options:
        icon = builders[option](args.stills, args.out)
        render(icon, os.path.join(args.out, option, "renders"))
        print(icon)


if __name__ == "__main__":
    main()
