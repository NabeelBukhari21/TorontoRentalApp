// Copies the mascot art the compositions use from the app's asset catalog
// into public/, so there is one source of truth for the artwork.
import {copyFileSync, existsSync, mkdirSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const mascot = join(root, 'RentalApp/RentalApp/Resources/Assets.xcassets/Mascot');
const out = join(root, 'tools/motion/public');
mkdirSync(out, {recursive: true});

const files = {
  'MascotSit.png': join(mascot, 'MascotSit.imageset/MascotSit.png'),
  'MascotCheer.png': join(mascot, 'MascotCheer.imageset/MascotCheer.png'),
  'FaceSleepy.png': join(mascot, 'Faces/MascotFaceSleepy.imageset'),
  'FaceHappy.png': join(mascot, 'Faces/MascotFaceHappy.imageset'),
  // Cut by tools/mascot/head_cut.py; lives in the catalog once the app uses it.
  'MascotHead.png': existsSync(join(mascot, 'MascotHead.imageset/MascotHead.png'))
    ? join(mascot, 'MascotHead.imageset/MascotHead.png')
    : join(root, 'tools/mascot/out/MascotHead.png'),
};

for (const [name, source] of Object.entries(files)) {
  // Face image sets name their PNG after the set.
  const file = source.endsWith('.imageset')
    ? join(source, source.split('/').pop().replace('.imageset', '.png'))
    : source;
  if (!existsSync(file)) {
    console.error(`Missing ${file}`);
    process.exit(1);
  }
  copyFileSync(file, join(out, name));
}
console.log(`Synced ${Object.keys(files).length} images to public/`);
