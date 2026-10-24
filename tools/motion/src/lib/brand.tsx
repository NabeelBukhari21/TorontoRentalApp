import React from 'react';
import {Img, staticFile} from 'remotion';
import {display} from './fonts';
import {brand} from './palette';

// Fractions of the mark's side — the same numbers as PurrpertyLogoGeometry.
const G = {
  ground: 0.85,
  cat: 0.72,
  catFloor: 0.94,
  left: {cx: 0.165, w: 0.28, body: 0.23, roof: 0.15},
  right: {cx: 0.835, w: 0.26, body: 0.21, roof: 0.14},
  condo: {cx: 0.31, w: 0.19, h: 0.62, rows: 5},
  tower: {cx: 0.69, w: 0.16, h: 0.47, rows: 4},
};

const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

/**
 * The Purrperty mark: Purr in front of a little street of homes.
 * `build` holds one 0…1 progress per piece — ground, condo, tower, left
 * house, right house, cat — so each can pop up on its own beat.
 */
export const LogoMark: React.FC<{
  size: number;
  build?: [number, number, number, number, number, number];
}> = ({size: S, build = [1, 1, 1, 1, 1, 1]}) => {
  const [ground, condo, tower, left, right, cat] = build.map(clamp01);
  const gy = G.ground * S;

  const towerEl = (t: typeof G.condo, top: string, bottom: string, cap: string, p: number, id: string) => {
    const w = t.w * S;
    const h = t.h * S;
    const x = t.cx * S - w / 2;
    const win = w * 0.16;
    const cols = 2;
    const gapX = w * 0.18;
    const gapY = w * 0.14;
    const gridW = cols * win + gapX;
    return (
      <g transform={`translate(0 ${gy}) scale(1 ${Math.max(p, 0.001)}) translate(0 ${-gy})`} opacity={p > 0 ? 1 : 0}>
        <defs>
          <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={top} />
            <stop offset="1" stopColor={bottom} />
          </linearGradient>
        </defs>
        <rect x={x} y={gy - h} width={w} height={h} rx={w * 0.14} fill={`url(#${id})`} />
        <rect x={t.cx * S - w * 0.25} y={gy - h - w * 0.06} width={w * 0.5} height={w * 0.12} rx={w * 0.06} fill={cap} />
        {Array.from({length: t.rows}).map((_, r) =>
          Array.from({length: cols}).map((__, c) => (
            <rect
              key={`${r}-${c}`}
              x={t.cx * S - gridW / 2 + c * (win + gapX)}
              y={gy - h + w * 0.32 + r * (win + gapY)}
              width={win}
              height={win}
              rx={win * 0.28}
              fill={brand.sunnyLight}
            />
          )),
        )}
      </g>
    );
  };

  const house = (h: typeof G.left, wall: string, roof: string, door: string, p: number) => {
    const w = h.w * S;
    const bh = h.body * S;
    const rh = h.roof * S;
    const cx = h.cx * S;
    const topBody = gy - bh;
    const rw = w * 1.14;
    const rb = topBody + rh * 0.08;
    const dw = w * 0.24;
    const dh = bh * 0.52;
    const gap = w * 0.12;
    const x0 = cx - (dw * 2 + gap) / 2;
    return (
      <g transform={`translate(0 ${gy}) scale(1 ${Math.max(p, 0.001)}) translate(0 ${-gy})`} opacity={p > 0 ? 1 : 0}>
        <rect x={cx - w / 2} y={topBody} width={w} height={bh} rx={w * 0.07} fill={wall} />
        <path d={`M${cx - rw / 2},${rb} L${cx},${rb - rh} L${cx + rw / 2},${rb} Z`} fill={roof} strokeLinejoin="round" stroke={roof} strokeWidth={S * 0.012} />
        <rect x={x0} y={gy - dh} width={dw} height={dh} rx={dw * 0.5} fill={door} />
        <rect x={x0} y={gy - dh + dw / 2} width={dw} height={dh - dw / 2} fill={door} />
        <rect x={x0 + dw + gap} y={gy - bh * 0.34 - dw} width={dw} height={dw} rx={dw * 0.28} fill={brand.sunnyLight} />
      </g>
    );
  };

  const catSide = G.cat * S;
  const catTop = gy - catSide * G.catFloor;

  return (
    <div style={{position: 'relative', width: S, height: S}}>
      <svg width={S} height={S} style={{position: 'absolute', inset: 0, overflow: 'visible'}}>
        <defs>
          <linearGradient id="ground" x1="0" x2="1">
            <stop offset="0" stopColor={brand.coral} />
            <stop offset="0.25" stopColor={brand.sunny} />
            <stop offset="0.5" stopColor={brand.mint} />
            <stop offset="0.75" stopColor={brand.sky} />
            <stop offset="1" stopColor={brand.violet} />
          </linearGradient>
        </defs>
        <line
          x1={S * 0.04}
          x2={S * 0.04 + S * 0.92 * ground}
          y1={gy}
          y2={gy}
          stroke="url(#ground)"
          strokeWidth={Math.max(S * 0.028, 1.5)}
          strokeLinecap="round"
          opacity={ground > 0 ? 1 : 0}
        />
        {towerEl(G.condo, brand.violetLight, brand.violet, brand.violetDeep, condo, 'condo')}
        {towerEl(G.tower, brand.skyLight, brand.sky, brand.skyDeep, tower, 'tower')}
        {house(G.left, brand.wallSunny, brand.coral, brand.violet, left)}
        {house(G.right, brand.wallSky, brand.mint, brand.coral, right)}
      </svg>
      <Img
        src={staticFile('MascotSit.png')}
        style={{
          position: 'absolute',
          left: (S - catSide) / 2,
          top: catTop + (1 - cat) * S * 0.35,
          width: catSide,
          height: catSide,
          opacity: cat,
        }}
      />
    </div>
  );
};

/** "Purr" in the violet→sky gradient, "perty" in ink — the app's wordmark, in Fredoka. */
export const Wordmark: React.FC<{
  size: number;
  /** 0…1 per letter reveal; letters spring up in order. */
  reveal?: number;
  letterSpring?: (index: number) => number;
}> = ({size, letterSpring}) => {
  const letters = 'Purrperty'.split('');
  return (
    <div
      style={{
        fontFamily: display,
        fontWeight: 700,
        fontSize: size,
        letterSpacing: -size * 0.02,
        display: 'flex',
        lineHeight: 1,
      }}
    >
      {letters.map((ch, i) => {
        const p = letterSpring ? letterSpring(i) : 1;
        const isPurr = i < 4;
        return (
          <span
            key={i}
            style={{
              display: 'inline-block',
              transform: `translateY(${(1 - p) * size * 0.6}px) scale(${0.6 + 0.4 * p})`,
              opacity: Math.min(1, p * 1.4),
              ...(isPurr
                ? {
                    background: `linear-gradient(135deg, ${brand.violet}, ${brand.skyDeep})`,
                    WebkitBackgroundClip: 'text',
                    color: 'transparent',
                  }
                : {color: brand.ink}),
            }}
          >
            {ch}
          </span>
        );
      })}
    </div>
  );
};
