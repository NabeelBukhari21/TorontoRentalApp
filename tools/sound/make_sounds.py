#!/usr/bin/env python3
"""Synthesizes the app's sound effects (no samples, nothing licensed).

    python3 tools/sound/make_sounds.py      # needs numpy

Everything is tuned to C major pentatonic, so any two cues that overlap
still sound right together. Writes 44.1 kHz mono WAVs to Resources/Sounds.
"""
import pathlib
import wave

import numpy as np

SR = 44_100
OUT = pathlib.Path(__file__).resolve().parents[2] / "RentalApp/RentalApp/Resources/Sounds"
rng = np.random.default_rng(7)

C5, D5, E5, G5, A5, C6, D6, E6, G6 = 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.5, 1567.98


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(x, attack=0.003, decay=0.2):
    return np.minimum(x / attack, 1) * np.exp(-x / decay)


def lowpass(x, cutoff):
    """One-pole, run twice. `cutoff` may be an array."""
    a = 1 - np.exp(-2 * np.pi * np.broadcast_to(cutoff, x.shape) / SR)
    for _ in range(2):
        y, out = 0.0, np.empty_like(x)
        for i in range(len(x)):
            y += a[i] * (x[i] - y)
            out[i] = y
        x = out
    return x


def mallet(f, seconds=0.45, decay=0.13, bright=0.35):
    """Soft marimba: a fundamental, its 4th partial and a felt knock."""
    x = t(seconds)
    body = np.sin(2 * np.pi * f * x) * env(x, 0.002, decay)
    bar = np.sin(2 * np.pi * f * 3.93 * x) * env(x, 0.001, decay * 0.28) * bright
    knock = lowpass(rng.standard_normal(len(x)), 2400) * env(x, 0.0005, 0.008) * 0.5
    return body + bar + knock


def glass(f, seconds=0.5, decay=0.16):
    x = t(seconds)
    return sum(a * np.sin(2 * np.pi * f * m * x) * env(x, 0.001, decay / m ** 0.6) for m, a in ((1, 1), (2.76, 0.28), (5.4, 0.1)))


def bloop(start, end, seconds=0.16, decay=0.07, curve=1.0):
    """A bubble: a sine that slides in pitch."""
    x = t(seconds)
    p = np.clip(x / (seconds * 0.6), 0, 1) ** curve
    f = start * (end / start) ** p
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(x, 0.004, decay)


def whoosh(seconds, low, high, up=True):
    x = t(seconds)
    p = x / seconds
    cutoff = low * (high / low) ** (p if up else 1 - p)
    return lowpass(rng.standard_normal(len(x)), cutoff) * np.sin(np.pi * np.clip(p, 0, 1)) ** 1.4


def mix(*parts):
    """(start seconds, gain, samples), summed."""
    n = max(int(s * SR) + len(x) for s, _, x in parts)
    out = np.zeros(n)
    for s, g, x in parts:
        i = int(s * SR)
        out[i:i + len(x)] += g * x
    return out


def save(name, x, peak=0.5):
    x = x / np.max(np.abs(x)) * peak
    fade = min(len(x), int(SR * 0.012))
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1), w.setsampwidth(2), w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def bubbles(seconds, count, low=300, high=1100):
    parts = []
    for i in range(count):
        s = seconds * (i + rng.random() * 0.8) / count
        f = low * (high / low) ** rng.random()
        parts.append((s, 0.3 + 0.5 * rng.random(), bloop(f, f * 1.7, 0.1, 0.04)))
    return mix(*parts)


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    # A felt key going down; quiet, it happens on every press.
    x = t(0.09)
    save("press", np.sin(2 * np.pi * np.cumsum(190 * np.exp(-x * 18) + 90) / SR) * env(x, 0.001, 0.022)
         + lowpass(rng.standard_normal(len(x)), 1800) * env(x, 0.0005, 0.006) * 0.5, 0.34)
    save("tap", mix((0, 1, bloop(700, 900, 0.07, 0.025))), 0.28)
    save("focus", mix((0, 1, glass(G5, 0.2, 0.05))), 0.16)

    # Answers climb the scale, so each option has its own note.
    for i, f in enumerate((C5, D5, E5, G5, A5)):
        save(f"select{i}", mix((0, 1, mallet(f)), (0.055, 0.45, mallet(f * 1.5, 0.4, 0.1))), 0.46)
    save("deselect", mix((0, 1, mallet(E5, 0.3, 0.07)), (0.06, 0.8, mallet(C5, 0.3, 0.07))), 0.3)

    # Moving on and back: liquid up, liquid down.
    save("advance", mix((0, 0.55, whoosh(0.42, 300, 2600)), (0.02, 0.9, bloop(260, 620, 0.22, 0.09)), (0.13, 0.5, bloop(520, 1050, 0.16, 0.06))), 0.4)
    save("back", mix((0, 0.45, whoosh(0.34, 300, 1900, up=False)), (0.0, 0.9, bloop(600, 260, 0.22, 0.09))), 0.34)

    save("tick", glass(E6, 0.4, 0.11), 0.28)
    for i, f in enumerate((C5, E5, G5)):
        save(f"done{i}", mix((0, 1, mallet(f, 0.5, 0.16)), (0.07, 0.7, mallet(f * 2, 0.5, 0.13))), 0.44)

    # The screen filling with liquid, and the paw button filling.
    save("flood", mix((0, 0.9, whoosh(0.9, 160, 1700)), (0.05, 0.5, bubbles(0.75, 12)), (0.6, 0.6, bloop(300, 900, 0.25, 0.1))), 0.42)
    save("fill", mix((0, 0.6, whoosh(0.45, 200, 1800)), (0.02, 0.7, bubbles(0.36, 6, 350, 900)), (0.34, 0.8, bloop(380, 1000, 0.18, 0.07))), 0.42)
    save("drop", mix((0, 1, bloop(950, 240, 0.12, 0.04)), (0.09, 0.9, bloop(240, 700, 0.2, 0.07)), (0.2, 0.5, mallet(G5, 0.5, 0.16))), 0.4)

    # The reward: a run up, a chord, and glitter.
    run = [(i * 0.075, 0.7, mallet(f, 0.6, 0.18)) for i, f in enumerate((C5, E5, G5, C6))]
    chord = [(0.32, 0.5, mallet(f, 1.3, 0.42)) for f in (C5, E5, G5, C6)]
    glitter = [(0.36 + i * 0.06 + rng.random() * 0.03, 0.16, glass(f, 0.5, 0.14)) for i, f in enumerate((C6, E6, G6, D6, G6, E6, C6 * 2, G6))]
    save("celebrate", mix(*run, *chord, *glitter), 0.5)

    for i, f in enumerate((C5, D5, E5, G5, A5, C6, D6)):
        save(f"deal{i}", mix((0, 0.35, whoosh(0.1, 900, 3200)), (0.015, 1, mallet(f, 0.3, 0.07))), 0.3)

    # Never a buzzer: two low, soft notes.
    save("error", mix((0, 1, mallet(233.08, 0.4, 0.12, 0.15)), (0.12, 1, mallet(196.0, 0.5, 0.16, 0.15))), 0.4)

    # Purr: a "mrrp?" that slides up, then a low motor.
    x = t(0.34)
    p = x / 0.34
    f0 = 420 + 330 * np.sin(np.pi * np.clip(p * 0.85, 0, 1)) ** 1.5
    f0 *= 1 + 0.035 * np.sin(2 * np.pi * 27 * x) * np.clip(1 - p * 2, 0, 1)
    phase = 2 * np.pi * np.cumsum(f0) / SR
    voice = sum(a * np.sin(k * phase) for k, a in ((1, 1), (2, 0.55), (3, 0.32), (4, 0.14), (5, 0.07)))
    voice *= np.sin(np.pi * np.clip(p, 0, 1)) ** 0.7
    x2 = t(1.1)
    motor = lowpass(rng.standard_normal(len(x2)), 420) * (0.5 + 0.5 * np.sin(2 * np.pi * 25 * x2)) ** 2
    motor *= np.sin(np.pi * x2 / 1.1) ** 0.8
    motor /= np.max(np.abs(motor))
    voice /= np.max(np.abs(voice))
    save("purr", mix((0, 0.8, voice), (0.28, 0.5, motor)), 0.4)


if __name__ == "__main__":
    main()
