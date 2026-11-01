#!/usr/bin/env python3
"""Synthétise les effets sonores et musiques de CARDVERSE (WAV 22 kHz mono)."""
import math
import os
import wave

import numpy as np

SR = 22050
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio")
rng = np.random.default_rng(3)


def t_(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.2, sustain=None):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4))
    rel = np.exp(-np.maximum(0, t - a) / max(r, 1e-4)) if sustain is None else np.ones(n)
    return e * rel


def sine(f, d, ph=0):
    return np.sin(2 * np.pi * f * t_(d) + ph)


def sweep(f0, f1, d, kind="sin"):
    t = t_(d)
    f = f0 * (f1 / f0) ** (t / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) if kind == "sin" else np.sign(np.sin(ph)) * 0.6


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, k):
    k = max(1, int(k))
    return np.convolve(x, np.ones(k) / k, mode="same")


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def pad(x, d):
    return np.concatenate([np.zeros(int(SR * d)), x])


def reverb(x, amt=0.3, delays=(0.031, 0.047, 0.071, 0.113)):
    out = np.concatenate([x, np.zeros(int(SR * 0.6))])
    for i, dl in enumerate(delays):
        n = int(SR * dl)
        for k in range(1, 6):
            g = amt * (0.6 ** k) / (i + 1)
            out[n * k:n * k + len(x)] += x * g
    return out


def chord(freqs, d, a=0.02, r=0.6, harm=(1, 0.5, 0.25)):
    out = np.zeros(int(SR * d))
    for f in freqs:
        for h, g in enumerate(harm, 1):
            out += sine(f * h, d) * g
    return out / len(freqs) * env(len(out), a, r)


def save(name, x, vol=0.8):
    x = np.asarray(x, np.float64)
    peak = np.max(np.abs(x)) or 1
    x = x / peak * vol
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


N = {n: 440 * 2 ** ((i - 9) / 12) for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def note(n, octave=4):
    return N[n] * 2 ** (octave - 4)


def sfx():
    save("click", sine(1200, 0.05) * env(int(SR * 0.05), 0.001, 0.015) + sine(2400, 0.05) * 0.3 * env(int(SR * 0.05), 0.001, 0.008), 0.5)
    save("hover", sine(900, 0.04) * env(int(SR * 0.04), 0.001, 0.01), 0.3)
    save("back", sweep(900, 500, 0.08) * env(int(SR * 0.08), 0.002, 0.04), 0.45)
    # déchirure : bruit granuleux filtré en crescendo
    n = noise(0.55)
    gr = (rng.random(len(n)) < 0.08).astype(float)
    tear = lowpass(n * (0.3 + gr * 2), 3) * np.linspace(0.3, 1, len(n)) * env(len(n), 0.01, 0.4)
    save("tear", tear, 0.7)
    save("tear_tick", lowpass(noise(0.04), 2) * env(int(SR * 0.04), 0.001, 0.01), 0.35)
    wh = lowpass(noise(0.45), 8) * np.sin(np.linspace(0, np.pi, int(SR * 0.45)))
    save("whoosh", wh, 0.6)
    save("flip", mix(lowpass(noise(0.12), 4) * env(int(SR * 0.12), 0.002, 0.04), sine(700, 0.1) * 0.3 * env(int(SR * 0.1), 0.001, 0.03)), 0.55)
    save("pop", mix(sweep(300, 900, 0.12) * env(int(SR * 0.12), 0.002, 0.05)), 0.5)
    save("flash", reverb(mix(lowpass(noise(0.5), 2) * env(int(SR * 0.5), 0.001, 0.12), sweep(2000, 200, 0.5) * 0.4 * env(int(SR * 0.5), 0.001, 0.2))), 0.7)
    # révélations par palier
    save("reveal_1", reverb(chord([note("C", 5), note("E", 5), note("G", 5)], 0.6, 0.005, 0.25), 0.2), 0.5)
    save("reveal_2", reverb(mix(chord([note("D", 5), note("F#", 5), note("A", 5)], 0.9, 0.005, 0.4), pad(chord([note("D", 6)], 0.6, 0.005, 0.3), 0.12)), 0.3), 0.6)
    arp = mix(*[pad(chord([f], 0.8, 0.003, 0.35), i * 0.07) for i, f in enumerate([note("E", 5), note("G#", 5), note("B", 5), note("E", 6), note("G#", 6)])])
    save("reveal_3", reverb(arp, 0.35), 0.7)
    boom = sweep(120, 40, 1.2) * env(int(SR * 1.2), 0.002, 0.5)
    choir = chord([note("A", 3), note("C#", 4), note("E", 4), note("A", 4), note("C#", 5)], 2.6, 0.4, 1.6, harm=(1, 0.6, 0.4, 0.3, 0.2))
    shimmer = mix(*[pad(sine(f, 1.6) * env(int(SR * 1.6), 0.01, 0.5) * 0.25, i * 0.09) for i, f in enumerate([note("A", 6), note("C#", 7), note("E", 7), note("A", 7)])])
    save("reveal_4", reverb(mix(boom, choir, pad(shimmer, 0.3)), 0.4), 0.85)
    rumble = lowpass(noise(2.2), 40) * np.linspace(0, 1, int(SR * 2.2)) ** 2
    save("rift", reverb(mix(rumble, sweep(60, 220, 2.2) * 0.4 * np.linspace(0, 1, int(SR * 2.2))), 0.3), 0.8)
    save("coin", mix(sine(1650, 0.25) * env(int(SR * 0.25), 0.001, 0.08), pad(sine(2200, 0.3) * env(int(SR * 0.3), 0.001, 0.1), 0.06)), 0.45)
    save("buy", reverb(mix(chord([note("C", 5), note("G", 5)], 0.4, 0.002, 0.15), pad(chord([note("C", 6), note("E", 6)], 0.5, 0.002, 0.2), 0.08)), 0.25), 0.55)
    save("error", sweep(300, 180, 0.25, "sq") * env(int(SR * 0.25), 0.002, 0.1), 0.35)
    # combat
    save("summon", reverb(mix(sweep(200, 800, 0.35) * env(int(SR * 0.35), 0.01, 0.15), lowpass(noise(0.35), 6) * 0.4 * env(int(SR * 0.35), 0.01, 0.12)), 0.3), 0.6)
    save("hit", mix(lowpass(noise(0.18), 3) * env(int(SR * 0.18), 0.001, 0.05), sweep(180, 60, 0.18) * env(int(SR * 0.18), 0.001, 0.08)), 0.75)
    save("hit_big", reverb(mix(lowpass(noise(0.4), 4) * env(int(SR * 0.4), 0.001, 0.12), sweep(140, 35, 0.5) * env(int(SR * 0.5), 0.001, 0.2)), 0.3), 0.85)
    save("death", reverb(mix(sweep(500, 80, 0.6) * env(int(SR * 0.6), 0.005, 0.3), lowpass(noise(0.6), 12) * 0.5 * env(int(SR * 0.6), 0.005, 0.2)), 0.35), 0.6)
    save("spell", reverb(mix(*[pad(sine(f, 0.4) * env(int(SR * 0.4), 0.003, 0.12), i * 0.04) for i, f in enumerate([880, 1320, 1760, 2640])]), 0.35), 0.5)
    save("fire", lowpass(noise(0.6), 3) * env(int(SR * 0.6), 0.02, 0.25) * (1 + 0.5 * np.sin(t_(0.6) * 40)), 0.6)
    save("freeze", reverb(mix(*[pad(sine(f, 0.5) * env(int(SR * 0.5), 0.001, 0.15), i * 0.03) for i, f in enumerate([2093, 2637, 3136, 4186, 3520])]), 0.4), 0.45)
    save("heal", reverb(mix(*[pad(chord([f], 0.6, 0.02, 0.3), i * 0.08) for i, f in enumerate([note("C", 5), note("E", 5), note("G", 5), note("C", 6)])]), 0.4), 0.5)
    save("shield", mix(sine(600, 0.3) * env(int(SR * 0.3), 0.002, 0.15), sine(900, 0.3) * env(int(SR * 0.3), 0.002, 0.1) * 0.5), 0.45)
    save("turn", reverb(mix(chord([note("G", 4), note("D", 5)], 0.5, 0.01, 0.25), pad(chord([note("G", 5)], 0.5, 0.01, 0.25), 0.1)), 0.3), 0.5)
    save("evolve", reverb(mix(sweep(200, 1600, 1.0) * env(int(SR * 1.0), 0.3, 0.4) * 0.5, pad(chord([note("C", 5), note("E", 5), note("G", 5), note("C", 6)], 1.2, 0.01, 0.6), 0.8)), 0.45), 0.7)
    win = mix(*[pad(chord([f, f * 1.26, f * 1.5], 0.5 if i < 3 else 1.6, 0.01, 0.3 if i < 3 else 1.0), i * 0.18) for i, f in enumerate([note("C", 4), note("E", 4), note("G", 4), note("C", 5)])])
    save("victory", reverb(win, 0.35), 0.8)
    lose = mix(*[pad(chord([f, f * 1.19], 0.7, 0.01, 0.5), i * 0.3) for i, f in enumerate([note("A", 4), note("F", 4), note("D", 4)])])
    save("defeat", reverb(lose, 0.35), 0.7)


def music(name, bpm, prog, bars, mood=0):
    beat = 60 / bpm
    total = bars * 4 * beat
    n = int(SR * total)
    out = np.zeros(n + SR * 2)
    for b in range(bars):
        root, third, fifth = prog[b % len(prog)]
        t0 = int(SR * b * 4 * beat)
        # nappe
        p = chord([root / 2, third / 2, fifth / 2, root], 4 * beat, 0.6, 2.0, harm=(1, 0.3, 0.15)) * 0.5
        out[t0:t0 + len(p)] += p
        # arpège cristallin
        seq = [root, fifth, third * 2, fifth, root * 2, fifth, third * 2, fifth]
        for k in range(8):
            f = seq[k] * (2 if mood else 1)
            s = sine(f, beat * 0.9) * env(int(SR * beat * 0.9), 0.003, 0.25) * 0.22
            i0 = t0 + int(SR * k * beat / 2)
            out[i0:i0 + len(s)] += s
        # basse et pulsation
        for k in range(4):
            s = sine(root / 4, beat * 0.8) * env(int(SR * beat * 0.8), 0.005, 0.3) * (0.5 if mood else 0.3)
            i0 = t0 + int(SR * k * beat)
            out[i0:i0 + len(s)] += s
            if mood:
                kk = lowpass(noise(0.08), 2) * env(int(SR * 0.08), 0.001, 0.02) * 0.25
                i1 = i0 + int(SR * beat / 2)
                out[i1:i1 + len(kk)] += kk
    out = reverb(out, 0.25)
    # boucle : on replie la queue sur le début
    tail = out[n:n + SR * 2]
    loop = out[:n].copy()
    loop[:len(tail)] += tail[:min(len(tail), n)]
    save(name, loop, 0.55)


def main():
    os.makedirs(OUT, exist_ok=True)
    sfx()
    A, C, D, E, F, G = note("A", 3), note("C", 4), note("D", 4), note("E", 4), note("F", 3), note("G", 3)
    music("music_menu", 84, [(A, C, E), (F, A, C), (C, E, G), (G, note("B", 3), D)], 8)
    music("music_battle", 112, [(note("D", 3), F, A), (note("A#", 3), D, F), (F, A, C), (C, E, G)], 8, mood=1)
    print("audio généré dans", OUT)


if __name__ == "__main__":
    main()
