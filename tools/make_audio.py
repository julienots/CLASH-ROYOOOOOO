"""Génère les effets sonores de combat et les musiques de Clash of Things (synthèse, aucun échantillon externe).

Usage : python3 tools/make_audio.py godot/assets/sounds
Nécessite numpy, scipy et ffmpeg (encodage Ogg Vorbis).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- outils
def T(d):
    return np.arange(int(d * SR)) / SR


def noise(d):
    return rng.uniform(-1, 1, int(d * SR))


def filt(x, kind, f, order=2):
    nyq = SR / 2
    if kind == 'bp':
        sos = signal.butter(order, [max(20, f[0]) / nyq, min(f[1], nyq * 0.99) / nyq], 'bandpass', output='sos')
    else:
        sos = signal.butter(order, min(f, nyq * 0.99) / nyq, kind, output='sos')
    return signal.sosfilt(sos, x)


def sweep_filter(x, f0, f1, q=4.0, steps=40):
    """Filtre passe-bande dont la fréquence glisse de f0 à f1 (whoosh)."""
    out = np.zeros_like(x)
    n = len(x)
    seg = n // steps + 1
    for i in range(steps):
        a, b = i * seg, min(n, (i + 1) * seg + seg)
        if a >= n:
            break
        f = f0 * (f1 / f0) ** (i / steps)
        bw = f / q
        y = filt(x[max(0, a - seg):b], 'bp', (f - bw, f + bw))
        y = y[a - max(0, a - seg):]
        w = np.hanning(len(y))
        out[a:a + len(y)] += y * w
    return out


def env(d, attack=0.005, decay=5.0):
    t = T(d)
    e = np.exp(-t * decay)
    na = max(1, int(attack * SR))
    e[:na] *= np.linspace(0, 1, na)
    return e


def adsr(d, a=0.01, dcy=0.1, s=0.7, r=0.2):
    n = int(d * SR)
    e = np.full(n, s)
    na, nd, nr = int(a * SR), int(dcy * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, max(na, 1))[:na]
    e[na:na + nd] = np.linspace(1, s, max(nd, 1))[:len(e[na:na + nd])]
    if nr > 0:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def tone(freq, d, shape='sine', f_end=None):
    t = T(d)
    f = np.full_like(t, freq) if f_end is None else freq * (f_end / freq) ** (t / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == 'sine':
        return np.sin(ph)
    if shape == 'saw':
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if shape == 'square':
        return np.sign(np.sin(ph))
    if shape == 'tri':
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1


def metal(base, d, partials=(1, 2.76, 5.4, 8.93, 13.3), decay=9.0):
    t = T(d)
    x = np.zeros_like(t)
    for i, p in enumerate(partials):
        x += np.sin(2 * np.pi * base * p * t + rng.uniform(0, 6)) * np.exp(-t * decay * (1 + i * 0.6)) / (1 + i * 0.5)
    return x


def crackle(d, density=300, decay=3.0, hp=1500):
    n = int(d * SR)
    x = np.zeros(n)
    idx = rng.integers(0, n, int(density * d))
    x[idx] = rng.uniform(-1, 1, len(idx))
    x = filt(x, 'highpass', hp)
    return x * np.exp(-T(d) * decay)


_ir = None


def reverb(x, wet=0.25, length=1.6):
    global _ir
    if _ir is None:
        t = T(length)
        _ir = rng.normal(0, 1, len(t)) * np.exp(-t * 4.2)
        _ir = filt(_ir, 'lowpass', 6000)
        _ir /= np.sqrt(np.sum(_ir ** 2))
    y = signal.fftconvolve(np.concatenate([x, np.zeros(int(length * SR))]), _ir)[:len(x) + int(length * SR)]
    dry = np.concatenate([x, np.zeros(int(length * SR))])
    return dry * (1 - wet) + y * wet * 3.0


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, delay, total=None):
    pad = np.zeros(int(delay * SR))
    return np.concatenate([pad, x])


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def trim(x, thresh=0.0008):
    idx = np.where(np.abs(x) > thresh)[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + int(0.02 * SR))
    y = x[:end].copy()
    fade = min(len(y), int(0.02 * SR))
    y[-fade:] *= np.linspace(1, 0, fade)
    return y


def save(path, x, stereo_width=0.0):
    x = np.tanh(x * 1.1) / np.tanh(1.1)
    x = np.clip(x, -1, 1)
    if stereo_width > 0:
        d = int(0.011 * SR)
        r = np.concatenate([np.zeros(d), x[:-d]])
        st = np.stack([x, x * (1 - stereo_width) + r * stereo_width], axis=1)
    else:
        st = np.stack([x, x], axis=1)
    pcm = (st * 32000).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        tmp = f.name
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '5', path], check=True)
    os.unlink(tmp)


# ---------------------------------------------------------------- effets de combat
def swoosh(d=0.2, f0=600, f1=3500, amp=0.6):
    return sweep_filter(noise(d), f0, f1, 3.0) * np.hanning(int(d * SR)) * amp * 3


def sfx_sword(v):
    base = [480, 540, 610][v]
    clang = metal(base, 0.5, decay=8) * 0.7
    click = filt(noise(0.012), 'highpass', 3000) * 0.9
    return trim(reverb(mix(swoosh(0.16, 900, 4200, 0.5), at(mix(click, clang), 0.09)), 0.18))


def sfx_heavy(v):
    t = T(0.6)
    thump = np.sin(2 * np.pi * np.cumsum(90 * (45 / 90) ** (t / 0.6)) / SR) * np.exp(-t * 7) * 1.2
    crunch = filt(noise(0.3), 'lowpass', 900) * env(0.3, 0.002, 12) * 0.8
    clang = metal(210 + v * 30, 0.5, decay=7) * 0.35
    return trim(reverb(mix(swoosh(0.25, 300, 1500, 0.6), at(mix(thump, crunch, clang), 0.18)), 0.22))


def sfx_stab(v):
    return trim(mix(swoosh(0.09, 1500, 5000, 0.3), at(mix(metal(1100 + v * 120, 0.18, decay=20) * 0.5, filt(noise(0.01), 'highpass', 4000) * 0.6), 0.06)))


def sfx_bow(v):
    t = T(0.25)
    twang = (np.sin(2 * np.pi * np.cumsum(220 * (150 / 220) ** (t / 0.25)) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(440 * (300 / 440) ** (t / 0.25)) / SR)) * np.exp(-t * 18)
    click = filt(noise(0.02), 'bandpass' if False else 'highpass', 2500) * env(0.02, 0.001, 150) * 0.8
    return trim(mix(click, twang * 0.7, at(swoosh(0.18, 2500, 6000, 0.35), 0.02)))


def sfx_arrow_hit(v):
    t = T(0.15)
    thunk = np.sin(2 * np.pi * np.cumsum(320 * (110 / 320) ** (t / 0.15)) / SR) * np.exp(-t * 30)
    return trim(mix(thunk, filt(noise(0.05), 'bp', (800, 3000)) * env(0.05, 0.001, 60) * 0.6))


def sfx_fire_cast(v):
    w = sweep_filter(noise(0.55), 250, 2200, 2.5) * np.hanning(int(0.55 * SR)) * 1.8
    return trim(reverb(mix(w, crackle(0.55, 200, 3, 2000) * 0.6, tone(180, 0.5, 'saw', 380) * env(0.5, 0.1, 5) * 0.12), 0.2))


def sfx_explode(v, big=False):
    d = 1.6 if big else 1.0
    t = T(d)
    boom = np.sin(2 * np.pi * np.cumsum(110 * (35 / 110) ** (t / d)) / SR) * np.exp(-t * (3 if big else 5)) * 1.4
    body = filt(noise(d), 'lowpass', 1400 if big else 2000) * env(d, 0.003, 3.5 if big else 6) * 1.2
    sub = filt(noise(d), 'lowpass', 120) * env(d, 0.01, 2.5) * (2.5 if big else 1.2)
    cr = crackle(d, 500, 3, 1200) * 0.8
    x = np.tanh(mix(boom, body, sub, cr) * 2.2) * 0.8
    return trim(reverb(x, 0.3, 2.0))


def sfx_meteor_fall(v):
    d = 1.1
    t = T(d)
    whistle = tone(1400, d, 'sine', 260) * np.minimum(1, t * 2) * 0.35
    roar = filt(noise(d), 'lowpass', 500) * (t / d) ** 2 * 1.5
    fire = sweep_filter(noise(d), 400, 1800, 2) * (t / d) * 1.2
    return mix(whistle, roar, fire)


def sfx_zap(v):
    d = 1.4
    crack = mix(*[at(filt(noise(0.04), 'highpass', 1800) * env(0.04, 0.0005, 70) * rng.uniform(0.5, 1), rng.uniform(0, 0.12)) for _ in range(9)])
    buzz = tone(55, 0.35, 'saw') * env(0.35, 0.002, 9) * 0.5
    buzz = filt(buzz, 'lowpass', 2500)
    thunder = filt(noise(d), 'lowpass', 220) * env(d, 0.05, 2.6) * 2.5
    thunder *= 1 + 0.6 * np.sin(2 * np.pi * 7 * T(d))
    return trim(reverb(mix(crack * 1.3, buzz, at(thunder, 0.08)), 0.3, 2.0))


def sfx_freeze(v):
    d = 1.3
    t = T(d)
    shimmer = np.zeros_like(t)
    for _ in range(18):
        f = rng.uniform(1800, 6500)
        st = rng.uniform(0, 0.4)
        shimmer += np.sin(2 * np.pi * f * t) * np.exp(-np.maximum(0, t - st) * rng.uniform(4, 9)) * (t > st) * rng.uniform(0.2, 0.6)
    wh = sweep_filter(noise(0.5), 3000, 800, 3) * np.hanning(int(0.5 * SR)) * 1.5
    crack = filt(noise(0.08), 'highpass', 2500) * env(0.08, 0.001, 40)
    return trim(reverb(mix(crack, wh, shimmer * 0.25), 0.35, 2.2))


def sfx_beam(v):
    d = 0.35
    t = T(d)
    hum = (tone(330, d, 'saw', 520) * 0.3 + tone(660, d, 'sine', 1040) * 0.3) * (1 + 0.5 * np.sin(2 * np.pi * 30 * t))
    hum = filt(hum, 'lowpass', 3000) * env(d, 0.01, 8)
    return trim(reverb(hum, 0.25))


def sfx_deploy(v):
    t = T(0.4)
    thud = np.sin(2 * np.pi * np.cumsum(140 * (55 / 140) ** (t / 0.4)) / SR) * np.exp(-t * 12)
    dust = filt(noise(0.4), 'lowpass', 1500) * env(0.4, 0.002, 10) * 0.5
    sparkle = mix(*[at(np.sin(2 * np.pi * f * T(0.25)) * env(0.25, 0.002, 18) * 0.15, i * 0.04) for i, f in enumerate([1568, 2093, 2637, 3136])])
    return trim(reverb(mix(sparkle, at(mix(thud, dust), 0.05)), 0.2))


def sfx_rattle(v):
    clicks = mix(*[at(filt(noise(0.015), 'bp', (900, 2600)) * env(0.015, 0.0005, 300) * rng.uniform(0.4, 1), rng.uniform(0, 0.45)) for _ in range(22)])
    return trim(reverb(clicks * 1.5, 0.2))


def sfx_death(v):
    d = 0.7
    poof = sweep_filter(noise(0.35), 2500, 500, 2) * np.hanning(int(0.35 * SR)) * 1.2
    ghost = tone(400, d, 'sine', 1100) * env(d, 0.05, 4) * 0.25 * (1 + 0.3 * np.sin(2 * np.pi * 9 * T(d)))
    return trim(reverb(mix(poof, at(ghost, 0.05)), 0.35))


def sfx_tower_hit(v):
    t = T(0.3)
    knock = np.sin(2 * np.pi * np.cumsum(180 * (90 / 180) ** (t / 0.3)) / SR) * np.exp(-t * 18)
    grit = filt(noise(0.2), 'bp', (400, 2500)) * env(0.2, 0.001, 25) * 0.6
    return trim(mix(knock, grit))


def sfx_collapse(v):
    d = 2.6
    t = T(d)
    rumble = filt(noise(d), 'lowpass', 180) * np.exp(-t * 1.4) * 3
    crumble = mix(*[at(filt(noise(0.06), 'bp', (300, 2500)) * env(0.06, 0.001, 50) * rng.uniform(0.3, 1), rng.uniform(0, 1.8) ** 1.4) for _ in range(70)])
    return trim(reverb(mix(sfx_explode(0, True) * 0.9, rumble, crumble * 0.9), 0.3, 2.5))


def sfx_fuse(v):
    return filt(noise(0.6), 'highpass', 3000) * (0.3 + 0.2 * np.sin(2 * np.pi * 23 * T(0.6))) * 0.5


# ---------------------------------------------------------------- instruments
def note_freq(n):
    """n : demi-tons par rapport à La 440."""
    return 440.0 * 2 ** (n / 12)


NOTE = {'C': -9, 'C#': -8, 'Db': -8, 'D': -7, 'D#': -6, 'Eb': -6, 'E': -5, 'F': -4, 'F#': -3, 'Gb': -3, 'G': -2, 'G#': -1, 'Ab': -1, 'A': 0, 'A#': 1, 'Bb': 1, 'B': 2}


def nf(name):
    """'D4' -> fréquence."""
    p, o = name[:-1], int(name[-1])
    return note_freq(NOTE[p] + (o - 4) * 12)


def brass(f, d, vel=1.0):
    t = T(d)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t * 3)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.zeros_like(t)
    bright = 0.35 + 0.65 * np.minimum(1, t * 12)
    for k in range(1, 14):
        x += np.sin(k * ph) / k * np.exp(-(k - 1) * (1.6 - bright))
    return x * adsr(d, 0.03, 0.1, 0.8, min(0.12, d * 0.3)) * vel * 0.35


def strings(f, d, vel=1.0):
    t = T(d)
    x = np.zeros_like(t)
    for det in (-0.06, 0.0, 0.07):
        ph = 2 * np.pi * np.cumsum(np.full_like(t, f * 2 ** (det / 12))) / SR
        x += 2 * ((ph / (2 * np.pi)) % 1) - 1
    x = filt(x, 'lowpass', min(4000, f * 6))
    return x * adsr(d, 0.12, 0.2, 0.85, min(0.3, d * 0.4)) * vel * 0.08


def pluck(f, d, vel=1.0):
    t = T(d)
    x = np.zeros_like(t)
    for k in range(1, 12):
        x += np.sin(2 * np.pi * f * k * t) / k ** 1.2 * np.exp(-t * (2.5 + k * 1.8))
    a = int(0.003 * SR)
    x[:a] *= np.linspace(0, 1, a)
    return x * vel * 0.4


def bell(f, d, vel=1.0):
    return metal(f, d, (1, 2.0, 3.01, 4.17, 5.43), decay=3.5) * vel * 0.25


def kick(vel=1.0):
    t = T(0.35)
    return np.sin(2 * np.pi * np.cumsum(130 * (42 / 130) ** (t / 0.12).clip(0, 1)) / SR) * np.exp(-t * 9) * vel


def snare(vel=1.0):
    t = T(0.25)
    return (filt(noise(0.25), 'bp', (1200, 7000)) * np.exp(-t * 16) * 0.9 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.5) * vel


def tom(f=100, vel=1.0):
    t = T(0.5)
    return np.sin(2 * np.pi * np.cumsum(f * 1.5 * (f / (f * 1.5)) ** (t / 0.1).clip(0, 1)) / SR) * np.exp(-t * 6) * vel


def hat(vel=1.0, open_=False):
    d = 0.25 if open_ else 0.06
    return filt(noise(d), 'highpass', 7000) * env(d, 0.001, 12 if open_ else 60) * vel * 0.4


def crash(vel=1.0):
    d = 1.8
    return filt(noise(d), 'highpass', 4000) * env(d, 0.002, 2.2) * vel * 0.45


# ---------------------------------------------------------------- composition
def render(events, total):
    out = np.zeros(int(total * SR) + SR * 3)
    for start, x in events:
        a = int(start * SR)
        out[a:a + len(x)] += x[:len(out) - a]
    return out


def chord_tones(root, minor):
    r = NOTE[root]
    return [r, r + (3 if minor else 4), r + 7]


def make_song(bpm, prog, melody, style):
    beat = 60.0 / bpm
    bars = len(prog)
    total = bars * 4 * beat
    ev = []
    for b, (root, minor) in enumerate(prog):
        t0 = b * 4 * beat
        ct = chord_tones(root, minor)
        # nappe de cordes
        for n in ct:
            ev.append((t0, strings(note_freq(n - 12), 4 * beat * 1.02, 1.0)))
        # basse
        bass_pat = [0, 0, 2, 3] if style == 'battle' else [0, 2]
        step = 4 * beat / len(bass_pat)
        for i, s in enumerate(bass_pat):
            n = ct[0] - 24 + (7 if i % 2 and style == 'battle' else 0)
            ev.append((t0 + i * step, pluck(note_freq(n), step * 1.4, 1.1)))
        # arpèges
        if style != 'battle' or b % 2 == 0:
            for i in range(8):
                n = ct[i % 3] + (12 if i >= 4 else 0)
                ev.append((t0 + i * beat / 2, pluck(note_freq(n), beat * 0.9, 0.35)))
        # percussions
        for q in range(4):
            tq = t0 + q * beat
            if style == 'battle':
                ev.append((tq, kick(0.9 if q % 2 == 0 else 0.6)))
                if q % 2 == 1:
                    ev.append((tq, snare(0.7)))
                for h in range(2):
                    ev.append((tq + h * beat / 2, hat(0.5 if h else 0.7)))
                if q == 3 and b % 4 == 3:
                    for k in range(4):
                        ev.append((tq + k * beat / 4, tom(140 - k * 20, 0.6)))
            else:
                if q in (0, 2):
                    ev.append((tq, kick(0.5)))
                ev.append((tq + beat / 2, hat(0.35)))
        if b % 8 == 0:
            ev.append((t0, crash(0.6 if style == 'battle' else 0.3)))
    # mélodie (cuivres en combat, cloches + cuivres doux au menu)
    t = 0.0
    for name, length in melody:
        d = length * beat
        if name != '-':
            f = nf(name)
            if style == 'battle':
                ev.append((t, brass(f, d * 0.95, 0.9)))
                ev.append((t, brass(f / 2, d * 0.95, 0.4)))
            else:
                ev.append((t, bell(f, max(d, 1.2), 0.8)))
                ev.append((t, brass(f, d * 0.9, 0.35)))
        t += d
    x = render(ev, total)
    # boucle propre : on replie la queue (réverbération) sur le début
    n = int(total * SR)
    tail = x[n:]
    x = x[:n].copy()
    x[:len(tail)] += tail[:n]
    x = reverb(x, 0.18, 1.2)[:n]
    return norm(x, 0.85)


def melody_battle():
    m = []
    a = [('D5', 1), ('A4', 0.5), ('D5', 0.5), ('F5', 1), ('E5', 1), ('D5', 0.5), ('C5', 0.5), ('Bb4', 1), ('C5', 1), ('A4', 1),
         ('Bb4', 1), ('C5', 0.5), ('D5', 0.5), ('E5', 1), ('C5', 1), ('D5', 2), ('-', 1), ('A4', 1)]
    b = [('F5', 1.5), ('E5', 0.5), ('D5', 1), ('C5', 1), ('Bb4', 1.5), ('C5', 0.5), ('D5', 2), ('G5', 1), ('F5', 1), ('E5', 1), ('C#5', 1),
         ('D5', 1), ('E5', 1), ('F5', 1), ('A5', 1)]
    for part in (a, b, a, b):
        total = sum(l for _, l in part)
        m += part + ([('-', 16 - total)] if total < 16 else [])
    return m


def melody_menu():
    a = [('E5', 1), ('G5', 1), ('C6', 1.5), ('B5', 0.5), ('A5', 1), ('G5', 1), ('E5', 2), ('F5', 1), ('A5', 1), ('G5', 1.5), ('F5', 0.5),
         ('E5', 1), ('D5', 1), ('C5', 2)]
    b = [('C5', 1), ('E5', 1), ('G5', 1), ('C6', 1), ('B5', 2), ('G5', 2), ('A5', 1), ('C6', 1), ('B5', 1), ('A5', 1), ('G5', 4)]
    m = []
    for part in (a, b, a, b):
        total = sum(l for _, l in part)
        m += part + ([('-', 16 - total)] if total < 16 else [])
    return m


def main(out):
    os.makedirs(out, exist_ok=True)
    sfx = {
        'sword': sfx_sword, 'heavy': sfx_heavy, 'stab': sfx_stab, 'bow': sfx_bow, 'arrow_hit': sfx_arrow_hit,
        'fire_cast': sfx_fire_cast, 'explode': sfx_explode, 'zap': sfx_zap, 'freeze': sfx_freeze, 'beam': sfx_beam,
        'deploy': sfx_deploy, 'rattle': sfx_rattle, 'death': sfx_death, 'tower_hit': sfx_tower_hit,
    }
    for name, fn in sfx.items():
        for v in range(3 if name in ('sword', 'heavy', 'stab', 'bow', 'arrow_hit', 'tower_hit', 'death') else 1):
            save(os.path.join(out, f'{name}_{v}.ogg'), norm(fn(v), 0.9), 0.3)
    save(os.path.join(out, 'big_boom_0.ogg'), norm(sfx_explode(0, True), 0.95), 0.4)
    save(os.path.join(out, 'meteor_fall_0.ogg'), norm(sfx_meteor_fall(0), 0.8), 0.3)
    save(os.path.join(out, 'collapse_0.ogg'), norm(sfx_collapse(0), 0.95), 0.4)
    save(os.path.join(out, 'fuse_0.ogg'), norm(sfx_fuse(0), 0.5))
    # fanfares
    beat = 0.16
    crown = mix(*[at(brass(nf(n), 0.5, 1.0), i * beat) for i, n in enumerate(['D5', 'F#5', 'A5'])], at(brass(nf('D6'), 0.9, 1.0), 3 * beat),
                at(bell(nf('D6'), 1.5), 3 * beat), at(crash(0.5), 3 * beat))
    save(os.path.join(out, 'crown_0.ogg'), norm(reverb(crown, 0.3), 0.9), 0.4)
    horn = mix(brass(nf('D4'), 0.9), brass(nf('A4'), 0.9), brass(nf('D5'), 0.9), kick(1.0), tom(90, 1.0), at(crash(0.8), 0.0))
    save(os.path.join(out, 'go_0.ogg'), norm(reverb(horn, 0.3), 0.95), 0.4)
    tick = mix(np.sin(2 * np.pi * 880 * T(0.12)) * env(0.12, 0.001, 35), tom(160, 0.7))
    save(os.path.join(out, 'tick_0.ogg'), norm(reverb(tick, 0.2), 0.8))
    vic = []
    seq = [('D5', 0, 0.3), ('D5', 0.3, 0.15), ('D5', 0.45, 0.15), ('F#5', 0.6, 0.3), ('A5', 0.9, 0.3), ('D6', 1.2, 1.4)]
    for n, s, d in seq:
        vic += [at(brass(nf(n), d, 1.0), s), at(brass(nf(n) / 2, d, 0.5), s)]
    vic += [at(mix(*[tom(70 + (k % 2) * 10, 0.5) for _ in range(1)]), k * 0.06) for k in range(20)]
    vic += [at(crash(1.0), 1.2), at(bell(nf('D6'), 2.5, 1.2), 1.2), at(strings(nf('D4'), 2.2, 2), 1.2), at(strings(nf('A4'), 2.2, 2), 1.2)]
    save(os.path.join(out, 'victory_0.ogg'), norm(reverb(mix(*vic), 0.3, 2.2), 0.95), 0.4)
    lose = [at(brass(nf(n), 0.55, 0.9), i * 0.45) for i, n in enumerate(['A4', 'G4', 'F4', 'D4'])]
    lose += [at(strings(nf('D3'), 2.4, 2), 0.0), at(strings(nf('F3'), 2.4, 2), 0.0), at(tom(60, 0.8), 1.35)]
    save(os.path.join(out, 'defeat_0.ogg'), norm(reverb(mix(*lose), 0.35, 2.2), 0.85), 0.4)
    vs = mix(swoosh(0.4, 200, 3000, 1.2), at(mix(sfx_explode(0) * 0.7, metal(150, 1.2, decay=3) * 0.6), 0.3))
    save(os.path.join(out, 'vs_0.ogg'), norm(reverb(vs, 0.3), 0.95), 0.4)
    chest = mix(sfx_deploy(0) * 0.6, at(sweep_filter(noise(0.8), 300, 4000, 2) * np.hanning(int(0.8 * SR)) * 2, 0.3),
                *[at(bell(nf(n), 1.2, 0.7), 0.9 + i * 0.07) for i, n in enumerate(['D6', 'F#6', 'A6', 'D7'])], at(crash(0.5), 0.9))
    save(os.path.join(out, 'chest_0.ogg'), norm(reverb(chest, 0.35, 2.0), 0.9), 0.4)
    # musiques
    prog_b = [('D', 1), ('D', 1), ('Bb', 0), ('C', 0), ('D', 1), ('F', 0), ('C', 0), ('A', 0)] * 2
    save(os.path.join(out, 'music_battle.ogg'), make_song(132, prog_b, melody_battle(), 'battle'), 0.5)
    save(os.path.join(out, 'music_final.ogg'), make_song(152, prog_b, melody_battle(), 'battle'), 0.5)
    prog_m = [('C', 0), ('G', 0), ('A', 1), ('F', 0), ('C', 0), ('F', 0), ('G', 0), ('C', 0)] * 2
    save(os.path.join(out, 'music_menu.ogg'), make_song(100, prog_m, melody_menu(), 'menu'), 0.5)


if __name__ == '__main__':
    main(sys.argv[1])
