"""Cut Purr's head out of the aligned sit pose.

The launch animation pops the head up from behind a horizon (or out of a
liquid blob), so only the head and collar are needed. The cut below the
collar is straight on purpose: it is always hidden behind whatever the head
rises from.

    python3 head_cut.py ../../RentalApp/RentalApp/Resources/Assets.xcassets/Mascot/MascotSit.imageset/MascotSit.png out/MascotHead.png

Coordinates are in the 1024² canvas `pipeline.py` produces, so they hold for
any re-export of the sit pose.
"""

import sys

import numpy as np
from PIL import Image

# Head and collar, in canvas pixels.
LEFT, TOP, RIGHT, BOTTOM = 196, 44, 764, 584
# The tail curls up beside the neck; everything left of this line and below
# TAIL_Y belongs to it, not the head.
TAIL_X, TAIL_Y = 300, 500
# Soften the straight bottom edge so it never shows a hard line mid-rise.
FEATHER = 14


def main(src: str, dst: str) -> None:
    image = Image.open(src).convert("RGBA")
    pixels = np.array(image)

    tail = np.zeros(pixels.shape[:2], dtype=bool)
    tail[TAIL_Y:, :TAIL_X] = True
    pixels[tail, 3] = 0

    head = pixels[TOP:BOTTOM, LEFT:RIGHT].copy()
    ramp = np.linspace(1.0, 0.0, FEATHER)
    head[-FEATHER:, :, 3] = (head[-FEATHER:, :, 3] * ramp[:, None]).astype(np.uint8)

    # Square canvas, head centred horizontally and sitting on the bottom
    # edge, so it scales and rises cleanly from the bottom.
    height, width = head.shape[:2]
    side = max(width, height)
    canvas = np.zeros((side, side, 4), dtype=np.uint8)
    x = (side - width) // 2
    canvas[side - height:, x:x + width] = head
    Image.fromarray(canvas).save(dst, optimize=True)
    print(f"{dst}: {side}x{side}, head {width}x{height}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
