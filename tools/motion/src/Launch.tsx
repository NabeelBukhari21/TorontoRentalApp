import React from 'react';
import {AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig, Easing} from 'remotion';
import {GooeyDefs, wavePath, wobblyCircle} from './lib/gooey';
import {brand, launchBackground, SCREEN} from './lib/palette';

// Purr's head: 190 pt wide at 3×, centred a little above the middle.
export const HEAD = {size: 570, cx: SCREEN.width / 2, cy: 1155} as const;

const Head: React.FC<{x?: number; y?: number; scaleX?: number; scaleY?: number; rotate?: number; opacity?: number}> = ({
  x = 0,
  y = 0,
  scaleX = 1,
  scaleY = 1,
  rotate = 0,
  opacity = 1,
}) => (
  <Img
    src={staticFile('MascotHead.png')}
    style={{
      position: 'absolute',
      width: HEAD.size,
      height: HEAD.size,
      left: HEAD.cx - HEAD.size / 2 + x,
      top: HEAD.cy - HEAD.size / 2 + y,
      // Squash and stretch from the chin, so it reads as landing.
      transformOrigin: '50% 100%',
      transform: `rotate(${rotate}deg) scale(${scaleX}, ${scaleY})`,
      opacity,
    }}
  />
);

/** A: the head rises from behind a rippling liquid horizon. */
export const LaunchPeekaboo: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = frame / fps;

  const rise = spring({frame: frame - 10, fps, config: {damping: 11, stiffness: 120, mass: 0.9}});
  const y = interpolate(rise, [0, 1], [720, 0]);
  // Velocity-ish: stretch while rising fast, squash on the overshoot.
  const prev = spring({frame: frame - 11, fps, config: {damping: 11, stiffness: 120, mass: 0.9}});
  const v = (rise - prev) * 10;
  const scaleY = 1 + Math.max(-0.08, Math.min(0.1, v * 0.35));
  const scaleX = 1 - (scaleY - 1) * 0.6;
  const tilt = Math.sin(Math.max(0, frame - 18) / 6) * 7 * Math.exp(-Math.max(0, frame - 18) / 22);

  const horizon = 1400;
  const settle = Math.exp(-Math.max(0, frame - 10) / 30);
  const bulge = {x: HEAD.cx, width: 220, height: 90 * rise * settle};
  const amplitude = 10 + 22 * settle;

  // Droplets flung up as the head breaks the surface, then pulled back in.
  const drops = [-260, -170, -90, 95, 180, 265].map((dx, i) => {
    const start = 14 + (i % 3) * 2;
    const life = Math.max(0, frame - start) / fps;
    const vy = -1150 - (i % 2) * 260;
    const dy = vy * life + 0.5 * 3400 * life * life;
    return {x: HEAD.cx + dx * (1 + life * 0.6), y: horizon - 10 + Math.min(dy, 40), r: 26 - (i % 3) * 5, live: frame >= start};
  });

  const fadeIn = interpolate(frame, [0, 8], [0, 1], {extrapolateRight: 'clamp'});

  return (
    <AbsoluteFill style={{background: launchBackground}}>
      <Head y={y} scaleX={scaleX} scaleY={scaleY} rotate={tilt} />
      <svg width={SCREEN.width} height={SCREEN.height} style={{position: 'absolute', inset: 0, opacity: fadeIn}}>
        <GooeyDefs blur={20} />
        <defs>
          <linearGradient id="sea" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={brand.wallViolet} />
            <stop offset="1" stopColor="#E7E2FF" />
          </linearGradient>
        </defs>
        <g filter="url(#goo)">
          <path d={wavePath(SCREEN.width, SCREEN.height, horizon, amplitude, t, bulge)} fill="url(#sea)" />
          {drops.map((d, i) => (d.live ? <circle key={i} cx={d.x} cy={d.y} r={d.r} fill={brand.wallViolet} /> : null))}
        </g>
      </svg>
    </AbsoluteFill>
  );
};

/** B: a violet drop falls, splashes into a blob, and the head pops out of it. */
export const LaunchDripPop: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = frame / fps;
  const impact = 16;

  const fall = interpolate(frame, [0, impact], [0, 1], {extrapolateRight: 'clamp', easing: Easing.in(Easing.quad)});
  const dropY = interpolate(fall, [0, 1], [-160, HEAD.cy]);
  const stretch = 1 + fall * 0.9;

  const blob = spring({frame: frame - impact, fps, config: {damping: 9, stiffness: 140}});
  const pop = spring({frame: frame - 30, fps, config: {damping: 8, stiffness: 150, mass: 0.8}});
  // The blob swells to carry the head, then settles back into a halo.
  const blobR = frame < impact ? 0 : interpolate(blob, [0, 1], [50, 330]) - pop * 40;
  const wobble = 0.09 * Math.exp(-Math.max(0, frame - impact) / 20) + 0.015;

  const splash = Array.from({length: 9}).map((_, i) => {
    const a = (i / 9) * Math.PI * 2 + 0.3;
    const life = Math.max(0, frame - impact) / fps;
    const dist = 520 * life - 900 * life * life;
    const r = 24 - (i % 3) * 5;
    const spread = Math.max(0, dist) * 1.1;
    // Only once clear of the blob: inside it they read as dark specks.
    return {x: HEAD.cx + Math.cos(a) * spread, y: HEAD.cy + 40 + Math.sin(a) * spread * 0.64, r, live: frame > impact && spread > 150};
  });

  const sparkle = (dx: number, dy: number, delay: number) => {
    const s = spring({frame: frame - 48 - delay, fps, config: {damping: 10}});
    const fade = interpolate(frame, [62 + delay, 74 + delay], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
    return (
      <path
        key={`${dx}`}
        d="M0,-1 L0.22,-0.22 L1,0 L0.22,0.22 L0,1 L-0.22,0.22 L-1,0 L-0.22,-0.22 Z"
        transform={`translate(${HEAD.cx + dx} ${HEAD.cy + dy}) scale(${34 * s})`}
        fill={brand.sunny}
        opacity={fade}
      />
    );
  };

  return (
    <AbsoluteFill style={{background: launchBackground}}>
      <svg width={SCREEN.width} height={SCREEN.height} style={{position: 'absolute', inset: 0}}>
        <GooeyDefs blur={18} />
        <defs>
          <radialGradient id="blob" cx="0.4" cy="0.35" r="0.75">
            <stop offset="0" stopColor={brand.violetLight} />
            <stop offset="1" stopColor={brand.violet} />
          </radialGradient>
        </defs>
        <g filter="url(#goo)" opacity={interpolate(pop, [0, 1], [1, 0.22])}>
          {frame < impact + 2 && (
            <ellipse cx={HEAD.cx} cy={dropY} rx={44 / Math.sqrt(stretch)} ry={44 * stretch} fill={brand.violet} />
          )}
          {blobR > 0 && <path d={wobblyCircle(HEAD.cx, HEAD.cy + 30, blobR, t * 3, wobble)} fill="url(#blob)" />}
          {splash.map((d, i) => (d.live ? <circle key={i} cx={d.x} cy={d.y} r={d.r} fill={brand.violet} /> : null))}
        </g>
      </svg>
      <Head
        y={interpolate(pop, [0, 1], [80, 0])}
        scaleX={interpolate(pop, [0, 1], [0.15, 1])}
        scaleY={interpolate(pop, [0, 1], [0.15, 1])}
        opacity={frame >= 30 ? 1 : 0}
      />
      <svg width={SCREEN.width} height={SCREEN.height} style={{position: 'absolute', inset: 0}}>
        {sparkle(-250, -250, 0)}
        {sparkle(270, -200, 5)}
        {sparkle(300, 60, 9)}
      </svg>
    </AbsoluteFill>
  );
};
