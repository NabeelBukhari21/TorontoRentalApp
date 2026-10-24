import {Config} from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');
// The fly-overs are WebGL; ANGLE is the renderer that works headless on macOS.
Config.setChromiumOpenGlRenderer('angle');
