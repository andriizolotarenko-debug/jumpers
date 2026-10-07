"""Synthesises the addon's sounds into media/sounds/ as OGG, one file per volume step.

WoW's PlaySoundFile has no volume argument, so the volume setting picks one of
four pre-mixed levels (25 / 50 / 75 / 100 %).
Run: python3 tools/make_sounds.py   (needs numpy and soundfile)
"""
import os

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "media", "sounds")
RATE = 44100
LEVELS = (25, 50, 75, 100)


def t_axis(dur):
    return np.arange(int(RATE * dur)) / RATE


def env(t, attack, decay):
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def bell(freq, dur, decay, partials=((1, 1.0), (2.01, 0.35), (3.0, 0.12), (4.2, 0.06))):
    t = t_axis(dur)
    s = sum(amp * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * k / decay) for k, amp in partials)
    return s * env(t, 0.004, 10)


def place(total, parts):
    out = np.zeros(int(RATE * total))
    for start, sig in parts:
        i = int(RATE * start)
        n = min(len(sig), len(out) - i)
        out[i:i + n] += sig[:n]
    return out


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    base, octave = name[:-1], int(name[-1])
    semis = names[base[0]] + (1 if base.endswith("#") else 0) + (octave - 4) * 12
    return 440.0 * 2 ** (semis / 12)


def tick():
    t = t_axis(0.06)
    return np.sin(2 * np.pi * 1900 * t) * env(t, 0.001, 0.012) * 0.5


def milestone():
    return place(0.6, [(0, bell(note("E5"), 0.5, 0.25) * 0.5), (0.11, bell(note("A5"), 0.5, 0.3) * 0.5)])


def tierup():
    return place(1.1, [(i * 0.07, bell(note(n), 0.9, 0.45) * 0.4) for i, n in enumerate(("C5", "E5", "G5", "C6"))])


def snap():
    t = t_axis(0.14)
    rnd = np.random.default_rng(3).standard_normal(len(t))
    sweep = np.sin(2 * np.pi * (900 * t + 5000 * t * t))
    return (0.35 * rnd + 0.6 * sweep) * env(t, 0.002, 0.03) * 0.5


def fanfare():
    def brass(freq, dur):
        t = t_axis(dur)
        s = sum(np.sin(2 * np.pi * freq * k * t) / k ** 1.3 for k in range(1, 7))
        return s * env(t, 0.02, dur * 0.6) * 0.3
    seq = [(0.00, "G4", 0.16), (0.16, "C5", 0.16), (0.32, "E5", 0.16), (0.48, "G5", 0.7)]
    parts = [(s, brass(note(n), d + 0.1)) for s, n, d in seq]
    parts += [(0.48, bell(note("C6"), 0.9, 0.5) * 0.3)]
    return place(1.3, parts)


def caption():
    return place(1.0, [(0, bell(note("G5"), 0.8, 0.5) * 0.45), (0.16, bell(note("D6"), 0.8, 0.55) * 0.4)])


SOUNDS = {"tick": tick, "milestone": milestone, "tierup": tierup, "snap": snap, "fanfare": fanfare, "caption": caption}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        sig = fn()
        sig = sig / max(1e-9, np.max(np.abs(sig))) * 0.9
        fade = min(len(sig), int(RATE * 0.01))
        sig[-fade:] *= np.linspace(1, 0, fade)
        for lv in LEVELS:
            sf.write(os.path.join(OUT, "%s_%d.ogg" % (name, lv)), sig * lv / 100, RATE, format="OGG", subtype="VORBIS")
    print(sorted(os.listdir(OUT)))
