// Renders every study to out/<id>.mp4 at review size (720×1560), H.264.
// Pass composition ids to render only those: node scripts/render-all.mjs LaunchA FlyoverB
import {execFileSync} from 'node:child_process';
import {mkdirSync} from 'node:fs';

const all = ['LaunchA', 'LaunchB', 'LogoA', 'LogoB', 'WelcomeA', 'WelcomeB', 'FlyoverA', 'FlyoverB'];
const ids = process.argv.slice(2).length ? process.argv.slice(2) : all;
mkdirSync('out', {recursive: true});

for (const id of ids) {
  console.log(`Rendering ${id}…`);
  execFileSync(
    'npx',
    ['remotion', 'render', 'src/index.ts', id, `out/${id}.mp4`, '--codec=h264', '--crf=23', '--scale=0.6667', '--log=error'],
    {stdio: 'inherit'},
  );
}
