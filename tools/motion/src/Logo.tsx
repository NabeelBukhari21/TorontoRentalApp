import React from 'react';
import {AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig, Easing} from 'remotion';
import {LogoMark, Wordmark} from './lib/brand';
import {GooeyDefs} from './lib/gooey';
import {brand, launchBackground, SCREEN} from './lib/palette';
import {HEAD} from './Launch';

const DOT_COLORS = [brand.violet, brand.sky, brand.mint, brand.sunny, brand.coral, brand.violetLight];
const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const lerp = (a: number, b: number, p: number) => a + (b - a) * p;

/** Shared opening: the head shrinks and melts into one liquid drop. */
const useMelt = () => {
  const frame = useCurrentFrame();
  const shrink = interpolate(frame, [4, 24], [1, 0], {...clamp, easing: Easing.in(Easing.cubic)});
  const drop = interpolate(frame, [12, 26], [0, 1], {...clamp, easing: Easing.out(Easing.back(2))});
  return {shrink, drop};
};

const MeltingHead: React.FC<{shrink: number}> = ({shrink}) => (
  <Img
    src={staticFile('MascotHead.png')}
    style={{
      position: 'absolute',
      width: HEAD.size,
      height: HEAD.size,
      left: HEAD.cx - HEAD.size / 2,
      top: HEAD.cy - HEAD.size / 2,
      transformOrigin: '50% 60%',
      transform: `scale(${shrink}) rotate(${(1 - shrink) * -25}deg)`,
      opacity: Math.min(1, shrink * 2.5),
    }}
  />
);

/** Ring of six dots, Cosmos style: each one swells in turn as the ring turns. */
const ring = (frame: number, radius: number, spin: number) =>
  DOT_COLORS.map((color, i) => {
    const a = (i / 6) * Math.PI * 2 - Math.PI / 2 + spin;
    const pulse = 0.5 + 0.5 * Math.sin(frame / 4 - i * 1.05);
    return {x: HEAD.cx + Math.cos(a) * radius, y: HEAD.cy + Math.sin(a) * radius, r: 30 + pulse * 10, color};
  });

/** A: the six dots orbit, then pull together into the logo tile; the name springs in. */
export const LogoOrbitMerge: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const {shrink, drop} = useMelt();

  const split = interpolate(frame, [24, 40], [0, 1], {...clamp, easing: Easing.out(Easing.back(1.6))});
  const gather = interpolate(frame, [74, 88], [0, 1], {...clamp, easing: Easing.in(Easing.cubic)});
  const spin = interpolate(frame, [24, 88], [0, Math.PI * 1.6], {...clamp, easing: Easing.inOut(Easing.sin)});
  const radius = 130 * split * (1 - gather);
  const dots = ring(frame, radius, spin);

  // The merged drop grows into the tile, then turns white as the mark builds.
  const tile = spring({frame: frame - 86, fps, config: {damping: 13, stiffness: 120}});
  const tileSide = 450 * tile;
  const whiten = interpolate(frame, [92, 104], [0, 1], clamp);
  const build = (order: number) => spring({frame: frame - 98 - order * 4, fps, config: {damping: 10, stiffness: 150}});
  const letter = (i: number) => spring({frame: frame - 108 - i * 2.2, fps, config: {damping: 11, stiffness: 170}});

  return (
    <AbsoluteFill style={{background: launchBackground}}>
      <MeltingHead shrink={shrink} />
      <svg width={SCREEN.width} height={SCREEN.height} style={{position: 'absolute', inset: 0}}>
        <GooeyDefs blur={16} />
        <g filter="url(#goo)">
          {frame < 90 && <circle cx={HEAD.cx} cy={HEAD.cy} r={70 * drop * (1 - split) + 60 * gather} fill={brand.violet} />}
          {frame < 90 && split > 0 && dots.map((d, i) => <circle key={i} cx={d.x} cy={d.y} r={d.r} fill={d.color} />)}
          {frame >= 86 && (
            <rect
              x={HEAD.cx - tileSide / 2}
              y={HEAD.cy - tileSide / 2}
              width={tileSide}
              height={tileSide}
              rx={lerp(tileSide / 2, tileSide * 0.23, tile)}
              fill={brand.violet}
              opacity={1 - whiten}
            />
          )}
        </g>
      </svg>
      {frame >= 92 && (
        <div
          style={{
            position: 'absolute',
            left: HEAD.cx - 225,
            top: HEAD.cy - 225,
            width: 450,
            height: 450,
            borderRadius: 450 * 0.23,
            background: brand.white,
            boxShadow: '0 30px 80px rgba(108,92,231,0.25)',
            opacity: whiten,
            overflow: 'hidden',
          }}
        >
          <div style={{position: 'absolute', left: 15, top: 15}}>
            <LogoMark size={420} build={[build(0), build(1), build(2), build(3), build(4), build(5)]} />
          </div>
        </div>
      )}
      <div style={{position: 'absolute', top: HEAD.cy + 290, width: '100%', display: 'flex', justifyContent: 'center'}}>
        <Wordmark size={150} letterSpring={letter} />
      </div>
    </AbsoluteFill>
  );
};

// Paw layout around the head's centre: a pad and four toes.
// Spaced so the liquid filter keeps the toes apart.
const PAW = [
  {x: -165, y: -100, r: 44},
  {x: -66, y: -182, r: 47},
  {x: 66, y: -182, r: 47},
  {x: 165, y: -100, r: 44},
  {x: 0, y: 25, r: 108},
];

/** B: the dots regroup into a paw print; the sixth stretches into an underline the name rises from. */
export const LogoPawPrint: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const {shrink, drop} = useMelt();

  const split = interpolate(frame, [24, 40], [0, 1], {...clamp, easing: Easing.out(Easing.back(1.6))});
  const spin = interpolate(frame, [24, 62], [0, Math.PI * 1.2], {...clamp, easing: Easing.inOut(Easing.sin)});
  const toPaw = spring({frame: frame - 58, fps, config: {damping: 12, stiffness: 110}});
  const lift = spring({frame: frame - 86, fps, config: {damping: 14, stiffness: 120}});
  const pawScale = lerp(1, 0.88, lift);
  const pawShiftY = lerp(0, -170, lift);

  const ringDots = ring(frame, 130 * split, spin);
  const lineY = HEAD.cy + 350;
  const bar = spring({frame: frame - 76, fps, config: {damping: 13, stiffness: 140}});

  const dots = ringDots.map((d, i) => {
    if (i < 5) {
      const p = PAW[i];
      return {
        x: lerp(d.x, HEAD.cx + p.x * pawScale, toPaw),
        y: lerp(d.y, HEAD.cy + p.y * pawScale + pawShiftY, toPaw),
        r: lerp(d.r, p.r * pawScale, toPaw),
        color: d.color,
      };
    }
    return {x: lerp(d.x, HEAD.cx, toPaw), y: lerp(d.y, lineY, toPaw), r: d.r, color: d.color};
  });

  const rise = spring({frame: frame - 92, fps, config: {damping: 13, stiffness: 120}});

  return (
    <AbsoluteFill style={{background: launchBackground}}>
      <MeltingHead shrink={shrink} />
      <svg width={SCREEN.width} height={SCREEN.height} style={{position: 'absolute', inset: 0}}>
        <GooeyDefs blur={16} />
        <defs>
          <linearGradient id="paw" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor={brand.violetLight} />
            <stop offset="1" stopColor={brand.violet} />
          </linearGradient>
        </defs>
        <g filter="url(#goo)">
          {split < 1 && <circle cx={HEAD.cx} cy={HEAD.cy} r={70 * drop * (1 - split)} fill={brand.violet} />}
          {split > 0 &&
            dots.slice(0, 5).map((d, i) => (
              <circle key={i} cx={d.x} cy={d.y} r={d.r} fill={toPaw > 0.6 ? 'url(#paw)' : d.color} />
            ))}
          {split > 0 && bar < 0.05 && <circle cx={dots[5].x} cy={dots[5].y} r={dots[5].r} fill={dots[5].color} />}
          {bar >= 0.05 && (
            <rect x={HEAD.cx - 230 * bar} y={lineY - 14} width={460 * bar} height={28} rx={14} fill={brand.coral} />
          )}
        </g>
      </svg>
      {/* The name rises out from behind the underline. */}
      <div
        style={{
          position: 'absolute',
          top: lineY - 190,
          height: 175,
          width: '100%',
          overflow: 'hidden',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'flex-end',
        }}
      >
        <div style={{transform: `translateY(${(1 - rise) * 190}px)`}}>
          <Wordmark size={150} />
        </div>
      </div>
    </AbsoluteFill>
  );
};
