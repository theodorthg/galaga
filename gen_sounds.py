#!/usr/bin/env python3
"""Placeholder SFX generator for galaga. Writes tiny 16-bit mono WAVs to
assets/sounds/. Real audio replaces these later; sound_manager.gd just needs
files at those keys."""
import math, struct, wave, os, random

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "sounds")


def w(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))
    print("wrote", path, len(samples), "samples")


def env(i, n, a=0.01, r=0.3):
    t = i / n
    at = a
    rt = r
    if t < at:
        return t / at
    if t > 1 - rt:
        return max(0.0, (1 - t) / rt)
    return 1.0


def tone(freq, dur, kind="sine", vol=1.0, fa=0.01, fr=0.3, sweep=1.0):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for i in range(n):
        f = freq * (sweep ** (i / n))
        ph += 2 * math.pi * f / SR
        if kind == "square":
            v = 1.0 if math.sin(ph) >= 0 else -1.0
        elif kind == "saw":
            v = (ph / math.pi) % 2 - 1
        elif kind == "noise":
            v = random.uniform(-1, 1)
        else:
            v = math.sin(ph)
        out.append(v * vol * env(i, n, fa, fr))
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    return [s / len(layers) for s in out]


os.makedirs(OUT, exist_ok=True)

# shoot — short high zap, pitch down
w("shoot", tone(880, 0.10, "square", 0.7, 0.005, 0.6, sweep=0.4))
# hit — bright tick + a little noise
w("hit", mix(tone(1200, 0.08, "square", 0.5, 0.002, 0.7, sweep=0.7),
             tone(300, 0.08, "noise", 0.3, 0.002, 0.9)))
# dive — descending swoop
w("dive", tone(700, 0.45, "saw", 0.5, 0.02, 0.5, sweep=0.35))
# player_boom — low noisy explosion
w("player_boom", mix(tone(90, 0.55, "noise", 0.9, 0.005, 0.8),
                     tone(70, 0.55, "square", 0.4, 0.01, 0.9, sweep=0.5)))
# extra — rising 3-note blip
w("extra", tone(523, 0.09, "square", 0.5, 0.01, 0.4) +
           tone(659, 0.09, "square", 0.5, 0.01, 0.4) +
           tone(784, 0.14, "square", 0.5, 0.01, 0.5))
# stage — two-note fanfare
w("stage", tone(440, 0.12, "square", 0.5, 0.01, 0.3) +
           tone(660, 0.20, "square", 0.5, 0.01, 0.4))

# music — ~4s loopable bass+blip pattern
notes = [220, 220, 262, 196, 220, 220, 294, 262]
mel = []
for k, base in enumerate(notes * 2):
    mel += mix(tone(base, 0.25, "saw", 0.35, 0.01, 0.2),
               tone(base * 2, 0.12, "square", 0.15, 0.01, 0.5) + [0.0] * (int(SR * 0.13)))
w("music", mel)
