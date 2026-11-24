// Copies the Purr stills the compositions use into public/. They are
// rendered from the app by tools/mascot/purr_stills.py.
import {copyFileSync, existsSync, mkdirSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const tools = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const stills = join(tools, 'mascot/stills');
const out = join(tools, 'motion/public');
mkdirSync(out, {recursive: true});

// The round-1 studies still ask for the old names.
const files = {
  'PurrCelebrate.png': 'classic_celebrate.png',
  'MascotHead.png': 'classic_dashboard.png',
  'MascotSit.png': 'classic_dashboard.png',
  'FaceSleepy.png': 'classic_blobSleep.png',
  'FaceHappy.png': 'classic_welcome.png',
};

for (const [name, source] of Object.entries(files)) {
  const file = join(stills, source);
  if (!existsSync(file)) {
    console.error(`Missing ${file}`);
    process.exit(1);
  }
  copyFileSync(file, join(out, name));
}
console.log(`Synced ${Object.keys(files).length} images to public/`);
