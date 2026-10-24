import React from 'react';
import {Composition} from 'remotion';
import {FlyoverDollhouse, FlyoverDroneSweep} from './Flyover';
import {LaunchDripPop, LaunchPeekaboo} from './Launch';
import {LogoOrbitMerge, LogoPawPrint} from './Logo';
import {SCREEN} from './lib/palette';
import {Welcome, WelcomeVariant} from './Welcome';

const screen = {width: SCREEN.width, height: SCREEN.height, fps: SCREEN.fps};

const welcomeA: WelcomeVariant = {button: 'orb', tagline: 'Every rental, under one paw.', terms: 'line', skip: 'sleepyCat'};
const welcomeB: WelcomeVariant = {button: 'paw', tagline: 'Your rentals, purring along.', terms: 'chip', skip: 'door'};

export const Root: React.FC = () => (
  <>
    {/* 1.1 Launch frame */}
    <Composition id="LaunchA" component={LaunchPeekaboo} durationInFrames={84} {...screen} />
    <Composition id="LaunchB" component={LaunchDripPop} durationInFrames={84} {...screen} />
    {/* Head → six dots → logo */}
    <Composition id="LogoA" component={LogoOrbitMerge} durationInFrames={150} {...screen} />
    <Composition id="LogoB" component={LogoPawPrint} durationInFrames={140} {...screen} />
    {/* 1.2 Welcome */}
    <Composition id="WelcomeA" component={Welcome} durationInFrames={176} defaultProps={welcomeA} {...screen} />
    <Composition id="WelcomeB" component={Welcome} durationInFrames={176} defaultProps={welcomeB} {...screen} />
    {/* Intro fly-over, after the welcome button */}
    <Composition id="FlyoverA" component={FlyoverDroneSweep} durationInFrames={276} {...screen} />
    <Composition id="FlyoverB" component={FlyoverDollhouse} durationInFrames={262} {...screen} />
  </>
);
