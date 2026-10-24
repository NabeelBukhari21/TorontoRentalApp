import React, {useMemo} from 'react';
import {AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig, Easing} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {Wordmark} from './lib/brand';
import {FEATURES, FeatureCard} from './lib/cards';
import {display} from './lib/fonts';
import {brand, SCREEN} from './lib/palette';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

// MARK: - City

/** Deterministic noise, so every render of the city is identical. */
const seeded = (seed: number) => () => {
  seed |= 0;
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

type Block = {x: number; z: number; w: number; d: number; h: number; color: string};

const WALLS = ['#FFFFFF', '#EDEBFA', brand.wallViolet, brand.wallSky, brand.wallMint, brand.wallSunny, '#F6F7FB'];
const CELL = 14;

/** A low-poly neighbourhood: a grid of blocks, taller toward the lake like downtown. */
const useCity = (): Block[] =>
  useMemo(() => {
    const rand = seeded(7);
    const blocks: Block[] = [];
    for (let gx = -7; gx <= 7; gx++) {
      for (let gz = -9; gz <= 3; gz++) {
        // A clear plaza around the hero building, so the camera can come close.
        if (Math.abs(gx) <= 1 && Math.abs(gz) <= 1) continue;
        if (rand() < 0.12) continue; // a park
        const downtown = Math.max(0, 1 - Math.hypot(gx + 3, gz + 5) / 5);
        // Low neighbours, so the hero building always stands out.
        const near = Math.hypot(gx, gz) < 3.6;
        const lots = rand() < 0.5 ? 1 : 2;
        for (let l = 0; l < lots; l++) {
          const w = lots === 1 ? 7 + rand() * 3 : 4 + rand() * 1.5;
          const d = 6 + rand() * 4;
          blocks.push({
            x: gx * CELL + (lots === 1 ? 0 : (l - 0.5) * 5.4),
            z: gz * CELL + (rand() - 0.5) * 2,
            w,
            d,
            h: near ? 2.5 + rand() * 4 : 2.5 + rand() * 6 + downtown * (8 + rand() * 26),
            color: WALLS[Math.floor(rand() * WALLS.length)],
          });
        }
      }
    }
    return blocks;
  }, []);

const City: React.FC = () => {
  const blocks = useCity();
  return (
    <group>
      {/* Ground, roads and the lake. */}
      <mesh rotation-x={-Math.PI / 2} receiveShadow>
        <planeGeometry args={[600, 600]} />
        <meshStandardMaterial color="#E9E6F6" />
      </mesh>
      {Array.from({length: 16}).map((_, i) => (
        <mesh key={`r${i}`} rotation-x={-Math.PI / 2} position={[(i - 7.5) * CELL, 0.02, -40]}>
          <planeGeometry args={[2.4, 260]} />
          <meshStandardMaterial color="#DCD8EE" />
        </mesh>
      ))}
      <mesh rotation-x={-Math.PI / 2} position={[0, 0.05, 140]}>
        <planeGeometry args={[600, 180]} />
        <meshStandardMaterial color="#BFE0FF" roughness={0.3} />
      </mesh>
      {blocks.map((b, i) => (
        <mesh key={i} position={[b.x, b.h / 2, b.z]} castShadow receiveShadow>
          <boxGeometry args={[b.w, b.h, b.d]} />
          <meshStandardMaterial color={b.color} roughness={0.85} />
        </mesh>
      ))}
      {/* A CN Tower nod on the waterfront. */}
      <group position={[-34, 0, 40]}>
        <mesh position={[0, 22, 0]} castShadow>
          <cylinderGeometry args={[0.7, 2.2, 44, 6]} />
          <meshStandardMaterial color="#F7F6FD" />
        </mesh>
        <mesh position={[0, 34, 0]} castShadow>
          <cylinderGeometry args={[3, 3, 3, 16]} />
          <meshStandardMaterial color={brand.wallViolet} />
        </mesh>
        <mesh position={[0, 52, 0]}>
          <cylinderGeometry args={[0.15, 0.5, 18, 6]} />
          <meshStandardMaterial color="#F7F6FD" />
        </mesh>
      </group>
    </group>
  );
};

// MARK: - The hero building

export const FLOORS = 6;
const FLOOR_H = 3;
const SIDE = 9;
// Which units are let (mint) or vacant (sunny), floor by floor.
const OCCUPANCY = [
  [1, 1, 0, 1],
  [1, 1, 1, 1],
  [0, 1, 1, 1],
  [1, 1, 1, 0],
  [1, 0, 1, 1],
  [1, 1, 1, 1],
];
// One tenant pin per floor, on the faces the camera sees: [floor, unit, initials].
const PINS: [number, number, string][] = [
  [0, 3, 'AO'],
  [1, 2, 'JM'],
  [2, 3, 'PK'],
  [3, 1, 'LS'],
  [4, 2, 'RT'],
  [5, 3, 'MN'],
];

/** A tenant pin: a white disc with initials and a coloured ring, always facing the camera. */
const Pin: React.FC<{position: [number, number, number]; label: string; ring: string; scale: number}> = ({position, label, ring, scale}) => {
  const texture = useMemo(() => {
    const c = document.createElement('canvas');
    c.width = c.height = 256;
    const g = c.getContext('2d')!;
    g.fillStyle = ring;
    g.beginPath();
    g.arc(128, 128, 124, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = '#FFFFFF';
    g.beginPath();
    g.arc(128, 128, 104, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = brand.ink;
    g.font = '700 92px Fredoka, sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText(label, 128, 134);
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    return t;
  }, [label, ring]);
  if (scale <= 0.001) return null;
  return (
    <sprite position={position} scale={[2.1 * scale, 2.1 * scale, 1]}>
      <spriteMaterial map={texture} depthTest={false} />
    </sprite>
  );
};

/**
 * Glass shell, floor slabs and units. `xray` fades the shell, `lit` lights
 * the units in order, `explode` lifts the floors apart like a dollhouse.
 */
const HeroBuilding: React.FC<{xray: number; lit: number; explode: number; pins: number}> = ({xray, lit, explode, pins}) => {
  const height = FLOORS * FLOOR_H;
  const unit = SIDE / 2 - 0.35;
  return (
    <group>
      <mesh position={[0, height / 2 + explode * FLOORS * 1.1, 0]} castShadow>
        <boxGeometry args={[SIDE + 0.3, height + 0.4, SIDE + 0.3]} />
        <meshStandardMaterial
          color={brand.violet}
          transparent
          opacity={(1 - xray * 0.86) * (1 - Math.min(1, explode * 3))}
          roughness={0.2}
          metalness={0.1}
          depthWrite={xray < 0.5}
        />
      </mesh>
      {OCCUPANCY.map((row, f) => {
        const y = f * FLOOR_H + explode * f * 2.4;
        return (
          <group key={f} position={[0, y, 0]}>
            <mesh position={[0, 0.15, 0]} receiveShadow>
              <boxGeometry args={[SIDE, 0.3, SIDE]} />
              <meshStandardMaterial color="#FFFFFF" />
            </mesh>
            {row.map((occupied, u) => {
              const ux = (u % 2 === 0 ? -1 : 1) * (SIDE / 4);
              const uz = (u < 2 ? -1 : 1) * (SIDE / 4);
              const order = f * 4 + u;
              const on = Math.min(1, Math.max(0, lit * 26 - order));
              const color = occupied ? brand.mint : brand.sunny;
              return (
                <group key={u}>
                  <mesh position={[ux, FLOOR_H / 2, uz]}>
                    <boxGeometry args={[unit, FLOOR_H - 0.6, unit]} />
                    <meshStandardMaterial
                      color={on > 0 ? color : '#F1EFFA'}
                      emissive={color}
                      emissiveIntensity={on * 0.35}
                      transparent
                      opacity={0.35 + on * 0.6}
                    />
                  </mesh>
                  {PINS.filter(([pf, pu]) => pf === f && pu === u).map(([, , label]) => (
                    <Pin
                      key={label}
                      // Just outside the facade, at the unit's window height.
                      position={[ux * 2.3, FLOOR_H * 0.6, uz * 2.3]}
                      label={label}
                      ring={[brand.violet, brand.sky, brand.mint, brand.coral][f % 4]}
                      scale={Math.min(1, Math.max(0, pins * 8 - f))}
                    />
                  ))}
                </group>
              );
            })}
          </group>
        );
      })}
    </group>
  );
};

// MARK: - Camera

type Key = {f: number; pos: [number, number, number]; look: [number, number, number]};

const sample = (keys: Key[], frame: number) => {
  let i = 0;
  while (i < keys.length - 2 && frame > keys[i + 1].f) i++;
  const a = keys[i];
  const b = keys[i + 1];
  const p = Easing.inOut(Easing.cubic)(Math.min(1, Math.max(0, (frame - a.f) / (b.f - a.f))));
  const mix = (u: number[], v: number[]) => u.map((x, k) => x + (v[k] - x) * p) as [number, number, number];
  return {pos: mix(a.pos, b.pos), look: mix(a.look, b.look)};
};

const Camera: React.FC<{keys: Key[]; orbit?: number}> = ({keys, orbit = 0}) => {
  const frame = useCurrentFrame();
  const camera = useThree((s) => s.camera);
  const {pos, look} = sample(keys, frame);
  // A slow drone drift around the target on top of the keyframed path.
  const a = orbit * frame;
  const x = (pos[0] - look[0]) * Math.cos(a) - (pos[2] - look[2]) * Math.sin(a) + look[0];
  const z = (pos[0] - look[0]) * Math.sin(a) + (pos[2] - look[2]) * Math.cos(a) + look[2];
  camera.position.set(x, pos[1], z);
  camera.lookAt(...look);
  camera.updateProjectionMatrix();
  return null;
};

const Lights: React.FC = () => (
  <>
    <hemisphereLight args={['#FFFFFF', '#C9C1F2', 0.75]} />
    <directionalLight
      position={[70, 110, 30]}
      intensity={2.4}
      castShadow
      shadow-mapSize-width={2048}
      shadow-mapSize-height={2048}
      shadow-camera-left={-120}
      shadow-camera-right={120}
      shadow-camera-top={120}
      shadow-camera-bottom={-120}
    />
  </>
);

const Stage: React.FC<{children: React.ReactNode}> = ({children}) => (
  <ThreeCanvas
    width={SCREEN.width}
    height={SCREEN.height}
    shadows
    camera={{fov: 42, near: 0.5, far: 900, position: [0, 100, 100]}}
    style={{background: 'linear-gradient(#EAE6FF, #FDFCFF 60%)'}}
  >
    <fog attach="fog" args={['#F3F0FF', 120, 420]} />
    <Lights />
    {children}
  </ThreeCanvas>
);

/** Feature chips that float out beside the building once the camera settles. */
const Chips: React.FC<{start: number; picks: number[]; spots: [number, number][]}> = ({start, picks, spots}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return (
    <>
      {picks.map((p, i) => {
        const s = spring({frame: frame - start - i * 9, fps, config: {damping: 12, stiffness: 140}});
        const [x, y] = spots[i];
        return (
          <div
            key={p}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              transform: `translateY(${(1 - s) * 50}px) scale(${0.7 + 0.3 * s}) rotate(${i % 2 ? 2 : -2}deg)`,
              opacity: s,
            }}
          >
            <FeatureCard feature={FEATURES[p]} scale={0.82} />
          </div>
        );
      })}
    </>
  );
};

const Caption: React.FC<{text: string; from: number; to: number}> = ({text, from, to}) => {
  const frame = useCurrentFrame();
  const o = interpolate(frame, [from, from + 10, to - 10, to], [0, 1, 1, 0], clamp);
  return (
    <div
      style={{
        position: 'absolute',
        top: 210,
        width: '100%',
        textAlign: 'center',
        fontFamily: display,
        fontWeight: 600,
        fontSize: 76,
        lineHeight: 1.1,
        color: brand.ink,
        opacity: o,
        transform: `translateY(${(1 - o) * 20}px)`,
        padding: '0 80px',
        boxSizing: 'border-box',
      }}
    >
      {text}
    </div>
  );
};

const Outro: React.FC<{from: number; withCat?: boolean}> = ({from, withCat}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const veil = interpolate(frame, [from, from + 14], [0, 1], clamp);
  const pop = spring({frame: frame - from - 6, fps, config: {damping: 10, stiffness: 140}});
  return (
    <AbsoluteFill style={{background: `rgba(253,252,255,${veil * 0.94})`, alignItems: 'center', justifyContent: 'center'}}>
      {withCat && (
        <Img
          src={staticFile('MascotCheer.png')}
          style={{width: 620, height: 620, transform: `scale(${pop}) translateY(${(1 - pop) * 200}px)`, marginBottom: 20}}
        />
      )}
      <div style={{transform: `scale(${0.8 + 0.2 * pop})`, opacity: pop}}>
        <Wordmark size={170} />
      </div>
    </AbsoluteFill>
  );
};

// MARK: - Variations

/** A: a high drone orbit dives to one tower, which turns to glass; units light up, tenants pop in. */
export const FlyoverDroneSweep: React.FC = () => {
  const frame = useCurrentFrame();
  const xray = interpolate(frame, [118, 150], [0, 1], clamp);
  const lit = interpolate(frame, [138, 200], [0, 1], clamp);
  const pins = interpolate(frame, [168, 214], [0, 1], clamp);
  const keys: Key[] = [
    {f: 0, pos: [120, 150, 170], look: [0, 0, -30]},
    {f: 70, pos: [70, 70, 70], look: [0, 4, 0]},
    {f: 130, pos: [30, 27, 36], look: [0, 7, 0]},
    {f: 270, pos: [28, 25, 38], look: [0, 7.5, 0]},
  ];
  return (
    <AbsoluteFill>
      <Stage>
        <Camera keys={keys} orbit={0.0028} />
        <City />
        <HeroBuilding xray={xray} lit={lit} explode={0} pins={pins} />
      </Stage>
      <Caption text="Every property, unit and tenant" from={20} to={120} />
      <Caption text="See who lives where, at a glance" from={140} to={215} />
      <Chips start={196} picks={[0, 1, 4, 2]} spots={[[50, 1520], [520, 1690], [40, 1880], [500, 2050]]} />
      <Outro from={246} />
    </AbsoluteFill>
  );
};

/** B: a flat map tilts into 3D, the camera pushes in and the floors lift apart like a dollhouse. */
export const FlyoverDollhouse: React.FC = () => {
  const frame = useCurrentFrame();
  const xray = interpolate(frame, [96, 120], [0, 1], clamp);
  const explode = interpolate(frame, [110, 168], [0, 1], {...clamp, easing: Easing.out(Easing.back(1.4))});
  const lit = interpolate(frame, [124, 190], [0, 1], clamp);
  const pins = interpolate(frame, [150, 200], [0, 1], clamp);
  const keys: Key[] = [
    {f: 0, pos: [0.5, 230, 6], look: [0, 0, 0]},
    {f: 60, pos: [80, 95, 80], look: [0, 0, 0]},
    {f: 120, pos: [34, 32, 34], look: [0, 12, 0]},
    {f: 240, pos: [30, 36, 36], look: [0, 15, 0]},
  ];
  return (
    <AbsoluteFill>
      <Stage>
        <Camera keys={keys} orbit={0.0018} />
        <City />
        <HeroBuilding xray={xray} lit={lit} explode={explode} pins={pins} />
      </Stage>
      <Caption text="Your whole portfolio, on one map" from={10} to={100} />
      <Caption text="Open any building, floor by floor" from={118} to={200} />
      <Chips start={176} picks={[6, 7, 0]} spots={[[60, 1700], [480, 1870], [70, 2040]]} />
      <Outro from={226} withCat />
    </AbsoluteFill>
  );
};
