#!/usr/bin/env python3
"""Render HingeLab's built-in accordion reed samples.

Writes mono 48 kHz 24-bit CAF files to App/Resources/Samples/ with a
sustain loop (`mark` chunk: slbg/slen) and the root note (`inst` chunk).

The loop is seamless by construction: the loop length L is a whole number
of periods of the middle reed, and the musette beat is exactly 1/L Hz, so
every partial of all three reeds completes whole cycles inside the loop.
Breath noise is generated with length L and tiled. A 12 ms crossfade covers
the sub-sample rounding of L.

Usage: python3 scripts/render-reed-samples.py
Deterministic (fixed seeds); re-running reproduces identical files.
"""
import os
import struct
import numpy as np

SR = 48_000
ATTACK_S = 0.12          # lead-in before the loop (reed speaking)
TARGET_LOOP_S = 0.8      # spec: sustain loops 0.4–0.8 s
PEAK_DBFS = -1.0         # spec: peak < −0.3 dBFS
ROOTS = {"C3": 48, "G3": 55, "C4": 60, "G4": 67}
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Samples")


def midi_hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def formant_gain(freq):
    """Free-reed spectrum: ~1/n^0.85 roll-off with a reed-chamber formant
    near 1.3 kHz, a second presence bump near 2.9 kHz, gentle top roll-off."""
    f1 = np.exp(-0.5 * ((np.log2(freq / 1300.0)) / 0.55) ** 2)
    f2 = np.exp(-0.5 * ((np.log2(freq / 2900.0)) / 0.45) ** 2)
    top = 1.0 / (1.0 + (freq / 7000.0) ** 4)
    return (0.55 + 1.4 * f1 + 0.6 * f2) * top


def render_reed(note, seed):
    rng = np.random.default_rng(seed)
    f0 = midi_hz(note)
    periods = max(1, round(TARGET_LOOP_S * f0))
    loop_s = periods / f0
    beat = 1.0 / loop_s                     # musette beat, one per loop
    loop_n = int(round(loop_s * SR))
    attack_n = int(ATTACK_S * SR)
    total_n = attack_n + loop_n
    t = np.arange(total_n) / SR

    signal = np.zeros(total_n)
    reeds = [(f0, 0.5), (f0 - beat, 0.25), (f0 + beat, 0.25)]
    for base, weight in reeds:
        n_max = int(15_000 // base)
        phases = rng.uniform(0, 2 * np.pi, n_max)
        for n in range(1, n_max + 1):
            fn = n * base
            amp = (n ** -0.85) * formant_gain(fn)
            signal += weight * amp * np.sin(2 * np.pi * fn * t + phases[n - 1])

    # Bellows breath: band-limited noise, periodic over the loop.
    noise = rng.standard_normal(loop_n)
    spectrum = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(loop_n, 1 / SR)
    shape = np.exp(-0.5 * (np.log2(np.maximum(freqs, 1) / 3200.0) / 0.9) ** 2)
    breath = np.fft.irfft(spectrum * shape, loop_n)
    breath /= np.max(np.abs(breath)) + 1e-12
    breath_full = np.tile(breath, int(np.ceil(total_n / loop_n)) + 1)
    breath_full = breath_full[(loop_n - attack_n % loop_n) % loop_n:][:total_n]
    signal = signal / np.max(np.abs(signal)) + 0.012 * breath_full

    # Reed speaking: brighter, slightly sharp onset settling in the lead-in.
    env = np.ones(total_n)
    rise = int(0.035 * SR)
    env[:rise] = np.sin(np.linspace(0, np.pi / 2, rise)) ** 2
    signal *= env

    # Cover sub-sample rounding of the loop length with a short crossfade
    # from the frames just before the loop start into the loop end.
    xf = int(0.012 * SR)
    loop_start, loop_end = attack_n, total_n
    w = np.sin(np.linspace(0, np.pi / 2, xf)) ** 2
    tail = signal[loop_end - xf:loop_end].copy()
    pre = signal[loop_start - xf:loop_start]
    signal[loop_end - xf:loop_end] = tail * (1 - w) + pre * w

    peak = 10 ** (PEAK_DBFS / 20)
    signal = signal / np.max(np.abs(signal)) * peak
    return signal.astype(np.float64), loop_start, loop_end, loop_s, beat


def caf_bytes(frames, loop_start, loop_end, base_note):
    out = bytearray()
    out += b"caff" + struct.pack(">HH", 1, 0)
    # desc: big-endian signed 24-bit integer PCM, mono
    out += b"desc" + struct.pack(">q", 32)
    out += struct.pack(">d", SR) + b"lpcm" + struct.pack(">IIIII", 0, 3, 1, 1, 24)
    # inst: base note
    out += b"inst" + struct.pack(">q", 28)
    out += struct.pack(">fBBBBfIIII", float(base_note), 0, 127, 1, 127, 0.0, 0, 0, 0, 0)
    # mark: sustain loop
    out += b"mark" + struct.pack(">q", 8 + 2 * 28) + struct.pack(">II", 0, 2)
    for kind, pos, mid in ((b"slbg", loop_start, 1), (b"slen", loop_end, 2)):
        out += kind + struct.pack(">dI", float(pos), mid) + b"\xff\xff\xff\xff\x00\x00\x00\x00" + struct.pack(">I", 0)
    ints = np.clip(np.round(frames * (2 ** 23)), -(2 ** 23), 2 ** 23 - 1).astype(np.int64)
    pcm = bytearray()
    u = (ints & 0xFFFFFF).astype(np.uint32)
    triple = np.stack([(u >> 16) & 0xFF, (u >> 8) & 0xFF, u & 0xFF], axis=1).astype(np.uint8)
    pcm += triple.tobytes()
    out += b"data" + struct.pack(">q", 4 + len(pcm)) + struct.pack(">I", 0) + pcm
    return bytes(out)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for i, (name, note) in enumerate(ROOTS.items()):
        frames, ls, le, loop_s, beat = render_reed(note, seed=4100 + i)
        path = os.path.join(OUT_DIR, f"hl_builtin_accordion_{name}_reed.caf")
        with open(path, "wb") as fh:
            fh.write(caf_bytes(frames, ls, le, note))
        jump = abs(frames[ls] - frames[le - 1])
        print(f"{os.path.basename(path)}: {len(frames)} frames, loop {ls}-{le} "
              f"({loop_s:.3f}s, beat {beat:.3f} Hz), loop-seam jump {jump:.4f}")


if __name__ == "__main__":
    main()
