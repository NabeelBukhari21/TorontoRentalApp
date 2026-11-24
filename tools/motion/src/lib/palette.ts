// Mirrors the app's design tokens (DS.Colors / PurrpertyBrand) so the
// studies match what SwiftUI draws. Keys keep the names the round-1
// studies used (violet is now cherry, sunny is gold…).
export const brand = {
  violet: '#CC2E2E',
  violetLight: '#F07870',
  violetDeep: '#B02727',
  violetSoft: '#FFF1E4',
  coral: '#F07870',
  sunny: '#F2B83A',
  sunnyLight: '#FFE6A8',
  mint: '#2ED8A3',
  sky: '#4DA8FF',
  skyDeep: '#B4501E',
  skyLight: '#FFD27A',
  ink: '#2B1712',
  secondary: '#765A52',
  surface: '#FFF6EC',
  white: '#FFFFFF',
  wallSunny: '#FFE9A6',
  wallMint: '#C4F2E3',
  wallSky: '#FFF1DA',
  wallViolet: '#FDE0DA',
} as const;

// Text-safe ("ink") accents for words on light backgrounds — WCAG AA.
export const ink = {
  violet: '#B02727',
  coral: '#B23A44',
  sunny: '#855600',
  mint: '#116F57',
  sky: '#0B60BE',
} as const;

/** The launch frame's light background. */
export const launchBackground = '#FFF4E4';

// Every composition is a phone screen at 3× (360×780 pt).
export const SCREEN = {width: 1080, height: 2340, fps: 30, pt: 3} as const;
