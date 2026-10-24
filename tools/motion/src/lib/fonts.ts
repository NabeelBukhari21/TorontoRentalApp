import {loadFont as loadFredoka} from '@remotion/google-fonts/Fredoka';
import {loadFont as loadFigtree} from '@remotion/google-fonts/Figtree';

// Fredoka for the brand (name, tagline); Figtree stands in for SF Pro in
// card and body text, which the browser renderer can't use.
export const display = loadFredoka('normal', {weights: ['500', '600', '700'], subsets: ['latin']}).fontFamily;
export const body = loadFigtree('normal', {weights: ['400', '500', '600', '700'], subsets: ['latin']}).fontFamily;
