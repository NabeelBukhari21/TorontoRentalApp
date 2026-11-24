# Purr's art

Purr is a Rive rig made in `/Users/admin/Projects/Rive/rentos-mascot`; the
app bundles its exports in `Resources/Mascot`. These scripts make the
still art around it.

- `purr_stills.py` renders moods as transparent PNGs from the Debug build
  in a simulator (`-PurrpertyStill <mood>`). `stills/` keeps the ones in use.
- `logo_icon.py` composes the layered Icon Composer app icon and renders
  every iOS appearance with `ictool`.

To update Purr: re-export there, then copy `export/*.riv` to
`Resources/Mascot` and `swift/PurrMood.swift` to `Components/Mascot/Purr`.
`PurrRig.swift` is ours (Rive's concurrency runtime), not a copy.
