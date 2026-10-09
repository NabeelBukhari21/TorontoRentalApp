# Mascot asset pipeline

Turns mascot artwork (illustrated on a white background) into the transparent,
aligned PNGs the app animates, and renders the logo/app icon from the same
geometry the SwiftUI logo uses.

## Why it exists

The cat is white on a white background, so "delete the white" punches holes in
the body. This pipeline only removes white that is **connected to the image
edges**, uses the darker contact line under the paws as a wall when removing
the baked-in floor shadow (the app draws its own, which stays on the ground
when the cat hops), drops the decorative motion dashes (the app animates its
own), and cleans the white fringe off the edges.

Every pose is placed on the **same 1024² canvas**, matched on eye spacing and
with the floor line at 94%, so swapping poses in the app looks like the cat
moving — not jumping.

## Adding a pose

```sh
pip install pillow numpy
python3 pipeline.py \
  --pose sit   "Cat Mascot.png" \
  --pose cheer "Cat Cheering.png" \
  --pose wave  "Cat Waving.png" \
  --pocket cheer 333 708 \
  --out out/
```

- The **first** `--pose` is the scale reference — keep it `sit`.
- `--pocket NAME X Y` marks a background gap that isn't connected to the edge
  (e.g. between the tail and the body), in source-image pixels.
- Check the results on a dark background before shipping; a white cat on
  white is exactly where mistakes hide.

Then add `mascot_<name>.png` to `Resources/Assets.xcassets/Mascot/` as an image
set and a case to `MascotPose` (with the `eyeY` / `headTopY` values from
`out/meta.json`).

## App icon

`logo_render.py` draws the same composition as `RentOSLogoMark`
(`RentOSLogoGeometry` holds the shared numbers — change both together).
