# Motion studies

Remotion compositions for Purrperty's onboarding motion: the launch frame,
the six-dot loader that becomes the logo, the welcome screen, and the 3D
intro fly-over. The studies are for choosing a direction. The app rebuilds
the chosen launch, loader and welcome motion in SwiftUI, and ships the
fly-over as an MP4 in `Resources/Media`.

```sh
python3 ../mascot/head_cut.py ../../RentalApp/RentalApp/Resources/Assets.xcassets/Mascot/MascotSit.imageset/MascotSit.png ../mascot/out/MascotHead.png
npm install
npm run studio                  # live preview
npm run render-all              # every study → out/*.mp4 (720×1560)
npm run render-all -- FlyoverA  # just one
```

`npm run sync-assets` copies the mascot art from the asset catalog into
`public/`, so the artwork has one source of truth. `src/lib/palette.ts`
mirrors the app's design tokens; keep the two in step.

Remotion is free for individuals and teams of up to three people; a larger
team needs a company licence.
