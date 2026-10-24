import React from 'react';
import {AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig, Easing} from 'remotion';
import {LogoMark, Wordmark} from './lib/brand';
import {FEATURES, FeatureCard} from './lib/cards';
import {body, display} from './lib/fonts';
import {GooeyDefs, wobblyCircle} from './lib/gooey';
import {brand, ink, SCREEN} from './lib/palette';

export type WelcomeVariant = {
  button: 'orb' | 'paw';
  tagline: string;
  terms: 'line' | 'chip';
  skip: 'sleepyCat' | 'door';
};

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
// Card width (560) plus breathing room; scaled with the row.
const CARD_STEP = 650;
const PRESS = 122;
const FLOOD = 140;

/** One endless row of drifting cards. Positive speed drifts right. */
const Marquee: React.FC<{y: number; cards: number[]; speed: number; offset?: number; scale?: number; tilt: number[]}> = ({
  y,
  cards,
  speed,
  offset = 0,
  scale = 1,
  tilt,
}) => {
  const frame = useCurrentFrame();
  const loop = cards.length * CARD_STEP * scale;
  return (
    <>
      {cards.map((c, i) => {
        const raw = i * CARD_STEP * scale + offset + frame * speed;
        const x = (((raw % loop) + loop) % loop) - CARD_STEP * scale;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: y + (i % 2 === 0 ? 0 : 46 * scale),
              transform: `rotate(${tilt[i % tilt.length]}deg)`,
            }}
          >
            <FeatureCard feature={FEATURES[c]} scale={scale} />
          </div>
        );
      })}
    </>
  );
};

const Background: React.FC = () => (
  <AbsoluteFill
    style={{
      background: [
        'radial-gradient(60% 40% at 8% 6%, #E7E2FF 0%, rgba(231,226,255,0) 70%)',
        'radial-gradient(55% 38% at 96% 14%, #FFE6D9 0%, rgba(255,230,217,0) 70%)',
        'radial-gradient(70% 40% at 10% 98%, #D9F6EC 0%, rgba(217,246,236,0) 70%)',
        'radial-gradient(60% 36% at 100% 92%, #E3F0FF 0%, rgba(227,240,255,0) 70%)',
        '#FFFFFF',
      ].join(', '),
    }}
  />
);

const glass: React.CSSProperties = {
  background: 'rgba(255,255,255,0.62)',
  border: '2px solid rgba(255,255,255,0.95)',
  boxShadow: '0 12px 36px rgba(27,27,47,0.10), inset 0 2px 0 rgba(255,255,255,0.9)',
  backdropFilter: 'blur(24px)',
};

/** A: a liquid orb with an arrow. Its edge ripples; pressed, it stretches and floods the screen. */
const OrbButton: React.FC<{cx: number; cy: number}> = ({cx, cy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = frame / fps;
  const press = spring({frame: frame - PRESS, fps, config: {damping: 9, stiffness: 180}});
  const release = frame > PRESS + 8 ? spring({frame: frame - PRESS - 8, fps, config: {damping: 12}}) : 0;
  const stretch = press * (1 - release);
  const flood = interpolate(frame, [FLOOD, FLOOD + 30], [0, 1], {...clamp, easing: Easing.in(Easing.cubic)});
  const r = 118;
  return (
    <svg width={SCREEN.width} height={SCREEN.height} style={{position: 'absolute', inset: 0}}>
      <GooeyDefs id="orb" blur={14} />
      <defs>
        <linearGradient id="orbFill" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={brand.violet} />
          <stop offset="1" stopColor={brand.coral} />
        </linearGradient>
      </defs>
      <g filter="url(#orb)">
        <g transform={`translate(${cx} ${cy}) scale(${1 + stretch * 0.9} ${1 - stretch * 0.18}) translate(${-cx} ${-cy})`}>
          <path d={wobblyCircle(cx, cy, r, t * 2.2, 0.035)} fill="url(#orbFill)" />
        </g>
        {flood > 0 && <circle cx={cx} cy={cy} r={r + flood * 2700} fill="url(#orbFill)" />}
      </g>
      {/* Glossy highlight and the arrow. */}
      <ellipse cx={cx - 34} cy={cy - 52} rx={52} ry={22} fill="rgba(255,255,255,0.35)" transform={`rotate(-20 ${cx - 34} ${cy - 52})`} />
      <path
        d={`M${cx - 34},${cy} H${cx + 30} M${cx + 6},${cy - 26} L${cx + 32},${cy} L${cx + 6},${cy + 26}`}
        stroke="#fff"
        strokeWidth={14}
        fill="none"
        strokeLinecap="round"
        strokeLinejoin="round"
        opacity={1 - flood}
      />
    </svg>
  );
};

/** B: a glass capsule with Purr's paw; holding it fills it with liquid, then it bursts. */
const PawButton: React.FC<{cx: number; cy: number}> = ({cx, cy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = frame / fps;
  const w = 600;
  const h = 184;
  const fill = interpolate(frame, [PRESS - 14, FLOOD], [0, 1], {...clamp, easing: Easing.inOut(Easing.sin)});
  const flood = interpolate(frame, [FLOOD, FLOOD + 30], [0, 1], {...clamp, easing: Easing.in(Easing.cubic)});
  // Starts below the capsule so no wave shows until it is pressed.
  const level = cy + h / 2 + 24 - fill * (h + 54);
  const wave = Array.from({length: 41})
    .map((_, i) => {
      const x = cx - w / 2 + (i / 40) * w;
      const y = level + Math.sin(i / 3 + t * 9) * 9 * (1 - fill * 0.6);
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
  const squeeze = 1 - spring({frame: frame - PRESS + 14, fps, config: {damping: 10}}) * 0.04 * (1 - flood);
  const pawColor = fill > 0.55 ? '#fff' : brand.violet;
  return (
    <>
      <div
        style={{
          position: 'absolute',
          left: cx - w / 2,
          top: cy - h / 2,
          width: w,
          height: h,
          borderRadius: h / 2,
          overflow: 'hidden',
          transform: `scale(${squeeze})`,
          ...glass,
        }}
      >
        <svg width={w} height={h} style={{position: 'absolute', inset: 0}} viewBox={`${cx - w / 2} ${cy - h / 2} ${w} ${h}`}>
          <defs>
            <linearGradient id="pawFill" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0" stopColor={brand.violet} />
              <stop offset="1" stopColor={brand.sky} />
            </linearGradient>
          </defs>
          <path d={`${wave} L${cx + w / 2},${cy + h} L${cx - w / 2},${cy + h} Z`} fill="url(#pawFill)" />
        </svg>
        <svg width={w} height={h} viewBox="-50 -50 100 100" style={{position: 'absolute', inset: 0}} preserveAspectRatio="xMidYMid meet">
          <g fill={pawColor} transform="scale(0.62)">
            <ellipse cx="0" cy="14" rx="22" ry="18" />
            <ellipse cx="-24" cy="-8" rx="8.5" ry="10.5" />
            <ellipse cx="-9" cy="-24" rx="9" ry="11" />
            <ellipse cx="9" cy="-24" rx="9" ry="11" />
            <ellipse cx="24" cy="-8" rx="8.5" ry="10.5" />
          </g>
        </svg>
      </div>
      {flood > 0 && (
        <svg width={SCREEN.width} height={SCREEN.height} style={{position: 'absolute', inset: 0}}>
          <GooeyDefs id="burst" blur={18} />
          <g filter="url(#burst)">
            <circle cx={cx} cy={cy} r={h / 2 + flood * 2700} fill={brand.violet} />
            {Array.from({length: 7}).map((_, i) => {
              const a = (i / 7) * Math.PI * 2;
              const d = 140 + flood * 900;
              return <circle key={i} cx={cx + Math.cos(a) * d} cy={cy + Math.sin(a) * d * 0.7} r={40} fill={brand.violet} />;
            })}
          </g>
        </svg>
      )}
    </>
  );
};

const Terms: React.FC<{kind: WelcomeVariant['terms']; y: number}> = ({kind, y}) => {
  const linkStyle: React.CSSProperties = {textDecoration: 'underline', textUnderlineOffset: 6, color: brand.secondary};
  if (kind === 'line') {
    return (
      <div style={{position: 'absolute', top: y, width: '100%', textAlign: 'center', fontFamily: body, fontSize: 36, color: brand.secondary}}>
        By continuing you agree to the <span style={linkStyle}>Terms</span> and <span style={linkStyle}>Privacy Policy</span>.
      </div>
    );
  }
  return (
    <div style={{position: 'absolute', top: y - 30, width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16}}>
      <div style={{fontFamily: body, fontSize: 34, color: brand.secondary}}>By continuing you agree to our</div>
      <div
        style={{
          ...glass,
          fontFamily: body,
          fontSize: 34,
          fontWeight: 600,
          color: brand.secondary,
          padding: '14px 30px',
          borderRadius: 999,
          display: 'flex',
          gap: 14,
          alignItems: 'center',
        }}
      >
        <svg width="34" height="34" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="10" fill="none" stroke={brand.secondary} strokeWidth="2" />
          <path d="M12 11v6M12 7.5v.5" stroke={brand.secondary} strokeWidth="2.4" strokeLinecap="round" />
        </svg>
        Terms · Privacy
      </div>
    </div>
  );
};

/** A: a sleepy Purr that wakes when tapped. B: a little door that swings open. */
const Skip: React.FC<{kind: WelcomeVariant['skip']}> = ({kind}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const tap = spring({frame: frame - 54, fps, config: {damping: 9, stiffness: 200}});
  const pressed = frame >= 54 && frame < 60;
  const awake = frame >= 56 && frame < 96;
  if (kind === 'sleepyCat') {
    const breathe = 1 + Math.sin(frame / 9) * 0.03;
    return (
      <div
        style={{
          ...glass,
          position: 'absolute',
          top: 150,
          right: 48,
          borderRadius: 999,
          padding: '12px 30px 12px 14px',
          display: 'flex',
          alignItems: 'center',
          gap: 16,
          transform: `scale(${pressed ? 0.94 : 1 + tap * 0.0})`,
        }}
      >
        <Img
          src={staticFile(awake ? 'FaceHappy.png' : 'FaceSleepy.png')}
          style={{width: 76, height: 76, transform: `scale(${awake ? 1.08 : breathe}) rotate(${awake ? -8 : 0}deg)`}}
        />
        <span style={{fontFamily: body, fontWeight: 700, fontSize: 38, color: ink.violet}}>Sign in</span>
      </div>
    );
  }
  const open = interpolate(frame % 120, [40, 56, 90, 104], [0, 1, 1, 0], clamp);
  return (
    <div
      style={{
        ...glass,
        position: 'absolute',
        top: 150,
        right: 48,
        borderRadius: 999,
        padding: '16px 30px 16px 22px',
        display: 'flex',
        alignItems: 'center',
        gap: 18,
      }}
    >
      <div style={{width: 46, height: 60, position: 'relative', perspective: 200}}>
        <div style={{position: 'absolute', inset: 0, borderRadius: 8, background: '#2A2550'}} />
        <div
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: 8,
            background: `linear-gradient(135deg, ${brand.violetLight}, ${brand.violet})`,
            transformOrigin: '0% 50%',
            transform: `rotateY(${-open * 70}deg)`,
          }}
        >
          <div style={{position: 'absolute', right: 9, top: 28, width: 7, height: 7, borderRadius: 4, background: brand.sunny}} />
        </div>
      </div>
      <span style={{fontFamily: body, fontWeight: 700, fontSize: 36, color: ink.violet}}>Have an account?</span>
    </div>
  );
};

export const Welcome: React.FC<WelcomeVariant> = (variant) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const enter = (delay: number) => spring({frame: frame - delay, fps, config: {damping: 14, stiffness: 120}});
  const letter = (i: number) => spring({frame: frame - 10 - i * 2, fps, config: {damping: 11, stiffness: 170}});
  const mark = enter(4);
  const buttonY = 1905;

  return (
    <AbsoluteFill style={{overflow: 'hidden'}}>
      <Background />
      <div style={{opacity: enter(0), transform: `translateY(${(1 - enter(0)) * -60}px)`}}>
        <Marquee y={300} cards={[0, 1, 2, 3, 4, 5]} speed={-3} tilt={[-4, 3, -2, 4, -3, 2]} />
        <Marquee y={600} cards={[6, 7, 8, 1, 3, 0]} speed={-2} offset={300} scale={0.88} tilt={[3, -3, 2, -2, 4, -4]} />
      </div>
      <div style={{opacity: enter(6), transform: `translateY(${(1 - enter(6)) * 60}px)`}}>
        <Marquee y={1500} cards={[5, 8, 1, 6, 3, 7]} speed={2.6} offset={120} scale={0.92} tilt={[2, -3, 4, -2, 3, -4]} />
      </div>

      <div style={{position: 'absolute', top: 830, left: SCREEN.width / 2 - 135, transform: `scale(${mark})`}}>
        <LogoMark size={270} />
      </div>
      <div style={{position: 'absolute', top: 1110, width: '100%', display: 'flex', justifyContent: 'center'}}>
        <Wordmark size={156} letterSpring={letter} />
      </div>
      <div
        style={{
          position: 'absolute',
          top: 1305,
          width: '100%',
          textAlign: 'center',
          fontFamily: display,
          fontWeight: 500,
          fontSize: 56,
          color: brand.secondary,
          opacity: enter(24),
        }}
      >
        {variant.tagline}
      </div>

      <div style={{opacity: enter(28)}}>
        <Skip kind={variant.skip} />
        <Terms kind={variant.terms} y={2120} />
      </div>
      <div style={{opacity: enter(20)}}>
        {variant.button === 'orb' ? <OrbButton cx={SCREEN.width / 2} cy={buttonY} /> : <PawButton cx={SCREEN.width / 2} cy={buttonY} />}
      </div>
    </AbsoluteFill>
  );
};
