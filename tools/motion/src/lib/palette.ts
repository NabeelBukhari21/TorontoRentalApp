// Mirrors the app's design tokens (DS.Colors / PurrpertyBrand) so the
// studies match what SwiftUI will draw.
export const brand = {
  violet: '#6C5CE7',
  violetLight: '#8F83F0',
  violetDeep: '#4B3BC9',
  violetSoft: '#EFEDFD',
  coral: '#FF6B6B',
  sunny: '#FFD93D',
  sunnyLight: '#FFF0A8',
  mint: '#2ED8A3',
  sky: '#4DA8FF',
  skyDeep: '#2A6BD4',
  skyLight: '#8CC6FF',
  ink: '#1B1B2F',
  secondary: '#6B7085',
  surface: '#F6F7FB',
  white: '#FFFFFF',
  wallSunny: '#FFE9A6',
  wallMint: '#C4F2E3',
  wallSky: '#D9ECFF',
  wallViolet: '#D9D4FB',
} as const;

// Text-safe ("ink") accents for words on light backgrounds — WCAG AA.
export const ink = {
  violet: '#5A4BD1',
  coral: '#C23B3B',
  sunny: '#8A6100',
  mint: '#0F7A5A',
  sky: '#1F6FC4',
} as const;

/** The launch frame's light background. */
export const launchBackground = '#F1EEFF';

// Every composition is a phone screen at 3× (360×780 pt).
export const SCREEN = {width: 1080, height: 2340, fps: 30, pt: 3} as const;
