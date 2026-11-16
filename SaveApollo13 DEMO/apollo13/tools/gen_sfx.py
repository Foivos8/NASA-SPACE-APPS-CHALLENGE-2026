#!/usr/bin/env python3
"""Synthesises the game's original sound effects into assets/audio/sfx/ (16-bit mono WAV, 44.1 kHz).

All of them are made from sine tones and filtered noise, in keeping with the
retro look of the game. Nothing here is sampled from a recording.

  ui_click.wav      toggle-switch click           buttons, opening a panel
  confirm.wav       soft rising two-note tone     correct answer, objective done
  error.wav         low double buzz               wrong answer, missed call
  latch.wav         metallic clunk                hatch, suit locks, docking
  tick.wav          short countdown pip           last ten seconds of the count
  master_alarm.wav  750 / 2000 Hz alternating     the accident (Apollo's alarm used these two tones)
  bang.wav          dull thump with rumble        the oxygen tank bursting
  vent_hiss.wav     gas hiss, fading              oxygen venting into space
  cabin_hum.wav     looping fans + 400 Hz whine   inside the Command Module (its AC power ran at 400 Hz)
  dice.wav          rattle                        dice challenge on the mission map
  thruster.wav      short gas puff                attitude thruster in the COAS challenge
  type_blip.wav     very soft short pip           letters appearing in dialogue and information boxes
  shutter.wav       camera double click           photographing Earth (Design Your Mission)
  collect.wav       three rising notes            a sample is picked up
  build.wav         ratchet and clunk             repairs and construction
  impact.wav        short thud and crunch         the rocket hits an obstacle
  warning.wav       two quick beeps               obstacles ahead

Run:  python3 tools/gen_sfx.py   (needs numpy)
"""
import os, wave
import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(13)


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def sine(freq, seconds, phase=0.0):
    return np.sin(2 * np.pi * freq * t(seconds) + phase)


def noise(seconds):
    return rng.uniform(-1, 1, int(SR * seconds))


def lowpass(x, cutoff):
    """One-pole low-pass, applied twice for a steeper slope."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    for _ in range(2):
        y = np.empty_like(x); acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(n, attack, release_shape=4.0):
    """Fast attack, exponential decay over the whole length."""
    e = np.exp(-release_shape * np.arange(n) / n)
    a = int(SR * attack)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def fade(x, seconds=0.005):
    n = min(int(SR * seconds), len(x) // 2)
    x[:n] *= np.linspace(0, 1, n); x[-n:] *= np.linspace(1, 0, n)
    return x


def save(name, x, peak=0.8):
    x = x / max(1e-9, np.max(np.abs(x))) * peak
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(f"{name:18s} {len(x) / SR:5.2f} s")


def ui_click():
    n = int(SR * 0.05)
    x = highpass(noise(0.05), 1500) * env(n, 0.0005, 9) + 0.5 * sine(2100, 0.05) * env(n, 0.0005, 14)
    tail = np.zeros(int(SR * 0.03)); k = int(SR * 0.018)
    tail[:k] += 0.35 * highpass(noise(0.018), 2500) * env(k, 0.0003, 8)      # the switch settling
    return np.concatenate([x, tail])


def confirm():
    a = sine(660, 0.09) * env(int(SR * 0.09), 0.004, 2.5)
    b = sine(990, 0.16) * env(int(SR * 0.16), 0.004, 3.5)
    return fade(np.concatenate([a, b]))


def error():
    def buzz(sec):
        x = np.sign(sine(110, sec)) * 0.6 + 0.4 * np.sign(sine(165, sec))
        return lowpass(x, 900) * env(int(SR * sec), 0.004, 1.5)
    return fade(np.concatenate([buzz(0.11), np.zeros(int(SR * 0.05)), buzz(0.16)]))


def latch():
    n = int(SR * 0.28)
    thud = sine(95, 0.28) * env(n, 0.001, 9)
    ring = (sine(1340, 0.28) + 0.6 * sine(2210, 0.28) + 0.4 * sine(3170, 0.28)) * env(n, 0.001, 16) * 0.35
    snap = np.zeros(n); k = int(SR * 0.012); snap[:k] = highpass(noise(0.012), 2000) * env(k, 0.0003, 5)
    return fade(thud + ring + 0.7 * snap)


def tick():
    return fade(sine(1000, 0.06) * env(int(SR * 0.06), 0.002, 3.0))


def master_alarm():
    sec = 2.4
    tt = t(sec)
    gate = (np.floor(tt * 5.0) % 2 == 0)                       # switches tone 5 times a second (2.5 Hz cycle)
    x = np.where(gate, np.sin(2 * np.pi * 750 * tt), np.sin(2 * np.pi * 2000 * tt) * 0.7)
    edge = np.abs(np.sin(np.pi * tt * 5.0)) ** 0.25           # softens each switch-over
    return fade(x * edge, 0.02)


def bang():
    sec = 1.6; n = int(SR * sec)
    tt = t(sec)
    sweep = np.sin(2 * np.pi * (38 * tt + 55 * (1 - np.exp(-tt * 9)) / 9)) * env(n, 0.002, 5)   # pitch drops from ~95 to ~40 Hz
    rumble = lowpass(noise(sec), 500) * env(n, 0.004, 3.2) * 1.6
    body = lowpass(noise(sec), 1600) * env(n, 0.002, 12) * 1.2         # mid-range, so small speakers carry it too
    crack = np.zeros(n); k = int(SR * 0.06); crack[:k] = lowpass(noise(0.06), 4500) * env(k, 0.0005, 5)
    return fade(0.5 * sweep + rumble + 3.0 * body + 2.0 * crack, 0.01)


def vent_hiss():
    sec = 3.0; n = int(SR * sec)
    x = highpass(lowpass(noise(sec), 6500), 1800)
    e = np.exp(-1.6 * np.arange(n) / n); a = int(SR * 0.08); e[:a] *= np.linspace(0, 1, a)
    wob = 1.0 + 0.15 * np.sin(2 * np.pi * 7 * t(sec))
    return fade(x * e * wob, 0.05)


def cabin_hum():
    sec = 4.0                                                   # every tone below fits a whole number of cycles in 4 s
    x = 0.55 * sine(60, sec) + 0.25 * sine(120, sec) + 0.10 * sine(400, sec) + 0.05 * sine(800, sec)
    k = int(SR * 0.5)
    raw = lowpass(noise(sec + 0.5), 700)
    n = int(SR * sec)
    air = raw[:n].copy()                                        # blend the first half second with what follows the
    ramp = np.linspace(0, 1, k)                                 # end, so the loop point has no seam
    air[:k] = raw[:k] * ramp + raw[n:n + k] * (1 - ramp)
    return x + 1.6 * air * (1.0 + 0.1 * np.sin(2 * np.pi * 0.5 * t(sec)))


def dice():
    sec = 0.55; n = int(SR * sec)
    x = np.zeros(n)
    for start in (0.0, 0.07, 0.13, 0.21, 0.27, 0.36, 0.43):
        k = int(SR * 0.03); i = int(SR * start)
        x[i:i + k] += highpass(noise(0.03), 1200) * env(k, 0.0005, 7) * rng.uniform(0.5, 1.0)
        x[i:i + k] += 0.4 * sine(rng.uniform(700, 1300), 0.03) * env(k, 0.0005, 10)
    return fade(x)


def thruster():
    sec = 0.22; n = int(SR * sec)
    e = np.exp(-3.0 * np.arange(n) / n); a = int(SR * 0.01); e[:a] *= np.linspace(0, 1, a)
    return fade(highpass(lowpass(noise(sec), 5000), 900) * e)


def type_blip():
    sec = 0.035; n = int(SR * sec)
    x = sine(560, sec) + 0.35 * sine(1120, sec)
    return fade(x * env(n, 0.003, 4.0), 0.004)


def shutter():
    sec = 0.22; n = int(SR * sec)
    x = np.zeros(n)
    for start, gain in ((0.0, 1.0), (0.09, 0.8)):
        k = int(SR * 0.03); i = int(SR * start)
        x[i:i + k] += highpass(noise(0.03), 2200) * env(k, 0.0005, 6) * gain
        x[i:i + k] += 0.3 * sine(1700, 0.03) * env(k, 0.0005, 9) * gain
    return fade(x, 0.004)


def collect():
    sec = 0.36; n = int(SR * sec)
    x = np.zeros(n)
    for j, f in enumerate((660, 880, 1320)):
        k = int(SR * 0.16); i = int(SR * 0.08 * j)
        x[i:i + k] += (sine(f, 0.16) + 0.3 * sine(f * 2, 0.16)) * env(k, 0.004, 4)
    return fade(x, 0.01)


def build():
    sec = 0.5; n = int(SR * sec)
    x = np.zeros(n)
    for start in (0.0, 0.07, 0.14, 0.21):                            # ratchet
        k = int(SR * 0.025); i = int(SR * start)
        x[i:i + k] += highpass(noise(0.025), 1500) * env(k, 0.0005, 7) * 0.7
        x[i:i + k] += 0.4 * sine(950, 0.025) * env(k, 0.0005, 8)
    k = int(SR * 0.18); i = int(SR * 0.3)                             # clunk
    x[i:i + k] += (sine(170, 0.18) + 0.5 * sine(410, 0.18)) * env(k, 0.002, 6) + lowpass(noise(0.18), 900) * env(k, 0.001, 9)
    return fade(x, 0.005)


def impact():
    sec = 0.45; n = int(SR * sec)
    tt = t(sec)
    thud = np.sin(2 * np.pi * (60 * tt + 80 * (1 - np.exp(-tt * 14)) / 14)) * env(n, 0.002, 6)
    crunch = lowpass(noise(sec), 2600) * env(n, 0.001, 9)
    return fade(thud + 1.4 * crunch, 0.008)


def warning():
    sec = 0.34; n = int(SR * sec)
    x = np.zeros(n)
    for start in (0.0, 0.17):
        k = int(SR * 0.11); i = int(SR * start)
        x[i:i + k] += (sine(980, 0.11) + 0.25 * sine(1960, 0.11)) * env(k, 0.004, 2.5)
    return fade(x, 0.006)


if __name__ == "__main__":
    save("ui_click.wav", ui_click(), 0.7)
    save("confirm.wav", confirm(), 0.6)
    save("error.wav", error(), 0.6)
    save("latch.wav", latch(), 0.8)
    save("tick.wav", tick(), 0.5)
    save("master_alarm.wav", master_alarm(), 0.6)
    save("bang.wav", bang(), 0.9)
    save("vent_hiss.wav", vent_hiss(), 0.5)
    save("cabin_hum.wav", cabin_hum(), 0.5)
    save("dice.wav", dice(), 0.7)
    save("thruster.wav", thruster(), 0.6)
    save("type_blip.wav", type_blip(), 0.45)
    save("shutter.wav", shutter(), 0.6)
    save("collect.wav", collect(), 0.55)
    save("build.wav", build(), 0.7)
    save("impact.wav", impact(), 0.85)
    save("warning.wav", warning(), 0.5)
