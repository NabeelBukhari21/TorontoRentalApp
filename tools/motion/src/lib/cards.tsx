import React from 'react';
import {body} from './fonts';
import {brand, ink} from './palette';

type Glyph = 'rent' | 'repair' | 'lease' | 'vacant' | 'chat' | 'ring' | 'visit' | 'vendor' | 'check';

/** Small line icons, stand-ins for the SF Symbols the app uses. */
const Icon: React.FC<{glyph: Glyph; color: string}> = ({glyph, color}) => {
  const s = {fill: 'none', stroke: color, strokeWidth: 3.2, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const};
  const paths: Record<Glyph, React.ReactNode> = {
    rent: (
      <>
        <rect x="6" y="11" width="28" height="19" rx="4" {...s} />
        <circle cx="20" cy="20.5" r="4" {...s} />
      </>
    ),
    repair: <path d="M25 8a7 7 0 0 0-8.6 8.6L8 25l3 3 8.4-8.4A7 7 0 0 0 28 11l-4 4-3-3z" {...s} />,
    lease: (
      <>
        <rect x="8" y="9" width="24" height="23" rx="4" {...s} />
        <path d="M8 16h24M14 6v6M26 6v6" {...s} />
      </>
    ),
    vacant: (
      <>
        <path d="M11 32V9h14v23M8 32h24" {...s} />
        <circle cx="21" cy="21" r="1.4" fill={color} />
      </>
    ),
    chat: <path d="M8 11a4 4 0 0 1 4-4h16a4 4 0 0 1 4 4v11a4 4 0 0 1-4 4H17l-7 6v-6a4 4 0 0 1-2-3.5z" {...s} />,
    ring: (
      <>
        <circle cx="20" cy="20" r="11" stroke="#E6E7F0" strokeWidth={5} fill="none" />
        <path d="M20 9a11 11 0 1 1-10.4 14.6" {...s} strokeWidth={5} />
      </>
    ),
    visit: (
      <>
        <circle cx="20" cy="20" r="12" {...s} />
        <path d="M20 13v7l5 3" {...s} />
      </>
    ),
    vendor: (
      <>
        <circle cx="20" cy="20" r="12" {...s} />
        <path d="M14.5 20.5l4 4 7-8" {...s} />
      </>
    ),
    check: (
      <>
        <path d="M20 7l11 4v8c0 7-5 12-11 14-6-2-11-7-11-14v-8z" {...s} />
        <path d="M15 20l3.5 3.5L25 17" {...s} />
      </>
    ),
  };
  return (
    <svg width="40" height="40" viewBox="0 0 40 40">
      {paths[glyph]}
    </svg>
  );
};

export type Feature = {glyph: Glyph; title: string; detail: string; tint: string; fg: string; initials?: string};

// Only things the app does today — the project rule for anything Purr says.
export const FEATURES: Feature[] = [
  {glyph: 'rent', title: 'Rent recorded', detail: '$2,150 · Unit 4B', tint: '#E2F8F0', fg: ink.mint},
  {glyph: 'repair', title: 'Repair booked', detail: 'Thu 10 am · Leaky tap', tint: '#FFECEB', fg: ink.coral},
  {glyph: 'lease', title: 'Lease renews', detail: 'In 60 days · N1 ready', tint: '#E6F2FF', fg: ink.sky},
  {glyph: 'vacant', title: 'Unit 12 is vacant', detail: 'Asking $2,400', tint: '#FFF6D6', fg: ink.sunny},
  {glyph: 'chat', title: 'Amara O.', detail: '“Thanks, the tap is fixed!”', tint: '#EFEDFD', fg: ink.violet, initials: 'AO'},
  {glyph: 'ring', title: 'October rent', detail: '$18.4K of $22K in', tint: '#E2F8F0', fg: ink.mint},
  {glyph: 'visit', title: 'Plumber arriving', detail: 'In 25 min · Unit 4B', tint: '#E6F2FF', fg: ink.sky},
  {glyph: 'vendor', title: 'Job accepted', detail: 'Tri-City Plumbing', tint: '#E2F8F0', fg: ink.mint},
  {glyph: 'check', title: 'Rent increase check', detail: 'Within Ontario guideline', tint: '#EFEDFD', fg: ink.violet},
];

/** A floating feature card, Luma-style: white, rounded, softly lifted. */
export const FeatureCard: React.FC<{feature: Feature; scale?: number}> = ({feature, scale = 1}) => (
  <div
    style={{
      width: 560 * scale,
      padding: `${30 * scale}px ${34 * scale}px`,
      borderRadius: 48 * scale,
      background: 'rgba(255,255,255,0.92)',
      border: '2px solid rgba(255,255,255,0.9)',
      boxShadow: '0 24px 60px rgba(27,27,47,0.10), 0 4px 12px rgba(27,27,47,0.05)',
      display: 'flex',
      alignItems: 'center',
      gap: 26 * scale,
      fontFamily: body,
      boxSizing: 'border-box',
    }}
  >
    <div
      style={{
        width: 92 * scale,
        height: 92 * scale,
        borderRadius: feature.initials ? '50%' : 28 * scale,
        background: feature.tint,
        display: 'grid',
        placeItems: 'center',
        flex: 'none',
        color: feature.fg,
        fontWeight: 700,
        fontSize: 34 * scale,
      }}
    >
      {feature.initials ?? (
        <div style={{transform: `scale(${1.5 * scale})`, display: 'grid'}}>
          <Icon glyph={feature.glyph} color={feature.fg} />
        </div>
      )}
    </div>
    <div style={{minWidth: 0}}>
      <div style={{fontSize: 36 * scale, fontWeight: 700, color: brand.ink, whiteSpace: 'nowrap'}}>{feature.title}</div>
      <div style={{fontSize: 29 * scale, fontWeight: 500, color: brand.secondary, whiteSpace: 'nowrap', marginTop: 4}}>
        {feature.detail}
      </div>
    </div>
  </div>
);
