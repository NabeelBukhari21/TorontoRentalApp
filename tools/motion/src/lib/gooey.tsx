import React from 'react';

/**
 * The liquid-morph look: blur everything inside, then crank alpha contrast
 * so overlapping blurs fuse into one smooth blob. Shapes drawn inside a
 * `<Gooey>` group merge and split like liquid.
 *
 * SwiftUI equivalent: a `Canvas` with `.addFilter(.alphaThreshold(min: 0.5))`
 * then `.addFilter(.blur(radius:))`.
 */
export const GooeyDefs: React.FC<{id?: string; blur?: number}> = ({id = 'goo', blur = 22}) => (
  <defs>
    <filter id={id} x="-50%" y="-50%" width="200%" height="200%" colorInterpolationFilters="sRGB">
      <feGaussianBlur in="SourceGraphic" stdDeviation={blur} result="blur" />
      <feColorMatrix
        in="blur"
        mode="matrix"
        values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 36 -16"
        result="goo"
      />
      <feComposite in="SourceGraphic" in2="goo" operator="atop" />
    </filter>
  </defs>
);

/** A closed blob path: a circle whose radius ripples with a few harmonics. */
export const wobblyCircle = (
  cx: number,
  cy: number,
  r: number,
  t: number,
  amount = 0.04,
  points = 64,
): string => {
  const parts: string[] = [];
  for (let i = 0; i <= points; i++) {
    const a = (i / points) * Math.PI * 2;
    const ripple =
      Math.sin(a * 3 + t * 2.1) * 0.5 + Math.sin(a * 5 - t * 1.7) * 0.3 + Math.sin(a * 2 + t * 1.3) * 0.2;
    const rr = r * (1 + amount * ripple);
    parts.push(`${i === 0 ? 'M' : 'L'}${(cx + Math.cos(a) * rr).toFixed(2)},${(cy + Math.sin(a) * rr).toFixed(2)}`);
  }
  return parts.join(' ') + ' Z';
};

/** A horizon whose top edge is a travelling wave; fills to the bottom. */
export const wavePath = (
  width: number,
  height: number,
  baseY: number,
  amplitude: number,
  t: number,
  bulge?: {x: number; height: number; width: number},
): string => {
  // Runs past both edges and the bottom, so the blur never rounds a corner on screen.
  const steps = 80;
  const overscan = 120;
  const parts: string[] = [`M${-overscan},${height + overscan}`];
  for (let i = 0; i <= steps; i++) {
    const x = -overscan + (i / steps) * (width + overscan * 2);
    let y =
      baseY +
      Math.sin(x / 140 + t * 3.2) * amplitude +
      Math.sin(x / 63 - t * 2.3) * amplitude * 0.45;
    if (bulge) {
      const d = (x - bulge.x) / bulge.width;
      y -= bulge.height * Math.exp(-d * d);
    }
    parts.push(`L${x.toFixed(1)},${y.toFixed(1)}`);
  }
  parts.push(`L${width + overscan},${height + overscan} Z`);
  return parts.join(' ');
};
