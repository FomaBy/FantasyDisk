#!/usr/bin/env python3
"""Generate procedural WAV audio assets for FantasyDisk.

Production helper, not used at runtime. Re-run to reproducibly rebuild
all SFX and music loops in assets/audio/.

Usage:
    python3 tools/generate_audio_assets.py
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


def write_wav(name, samples):
    path = os.path.join(OUTPUT_DIR, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            value = max(-1.0, min(1.0, sample))
            frames += struct.pack("<h", int(value * 32767))
        handle.writeframes(bytes(frames))
    print("wrote", path, f"({len(samples) / SAMPLE_RATE:.2f}s)")


def silence(duration):
    return [0.0] * int(SAMPLE_RATE * duration)


def tone(frequency, duration, volume=0.5, wave_shape="sine", attack=0.005, release=None):
    total = int(SAMPLE_RATE * duration)
    release = release if release is not None else duration * 0.6
    samples = []
    for index in range(total):
        t = index / SAMPLE_RATE
        phase = frequency * t
        if wave_shape == "square":
            raw = 1.0 if math.sin(TAU * phase) >= 0.0 else -1.0
            raw *= 0.35
        elif wave_shape == "triangle":
            raw = 2.0 * abs(2.0 * (phase - math.floor(phase + 0.5))) - 1.0
        elif wave_shape == "saw":
            raw = 2.0 * (phase - math.floor(phase + 0.5)) * 0.6
        else:
            raw = math.sin(TAU * phase)
        envelope = min(1.0, t / max(attack, 1e-5))
        time_left = duration - t
        if time_left < release:
            envelope *= max(0.0, time_left / release)
        samples.append(raw * volume * envelope)
    return samples


TAU = 2.0 * math.pi


def noise_burst(duration, volume=0.4, lowpass=0.25):
    rng = random.Random(1337)
    total = int(SAMPLE_RATE * duration)
    samples = []
    previous = 0.0
    for index in range(total):
        t = index / SAMPLE_RATE
        raw = rng.uniform(-1.0, 1.0)
        previous += lowpass * (raw - previous)
        envelope = max(0.0, 1.0 - t / duration) ** 2.2
        samples.append(previous * volume * envelope)
    return samples


def pitch_sweep(start_freq, end_freq, duration, volume=0.4, wave_shape="sine"):
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for index in range(total):
        t = index / SAMPLE_RATE
        progress = t / duration
        frequency = start_freq + (end_freq - start_freq) * progress
        phase += frequency / SAMPLE_RATE
        if wave_shape == "square":
            raw = (1.0 if math.sin(TAU * phase) >= 0.0 else -1.0) * 0.3
        else:
            raw = math.sin(TAU * phase)
        envelope = min(1.0, t / 0.004) * max(0.0, 1.0 - progress) ** 1.4
        samples.append(raw * volume * envelope)
    return samples


def mix(*layers):
    length = max(len(layer) for layer in layers)
    result = [0.0] * length
    for layer in layers:
        for index, sample in enumerate(layer):
            result[index] += sample
    return result


def concat(*parts):
    result = []
    for part in parts:
        result.extend(part)
    return result


def overlay_at(base, layer, offset_seconds):
    offset = int(SAMPLE_RATE * offset_seconds)
    needed = offset + len(layer)
    if len(base) < needed:
        base.extend([0.0] * (needed - len(base)))
    for index, sample in enumerate(layer):
        base[offset + index] += sample
    return base


NOTE_FREQS = {
    "A2": 110.00, "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.00,
    "A3": 220.00, "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00,
    "A4": 440.00, "C5": 523.25, "D5": 587.33, "E5": 659.26, "G5": 783.99, "A5": 880.00,
}


def build_sfx():
    write_wav("sfx_hit.wav", mix(
        noise_burst(0.09, volume=0.5, lowpass=0.4),
        pitch_sweep(320.0, 140.0, 0.09, volume=0.3),
    ))
    write_wav("sfx_player_hit.wav", mix(
        noise_burst(0.18, volume=0.45, lowpass=0.12),
        pitch_sweep(180.0, 60.0, 0.18, volume=0.5),
    ))
    write_wav("sfx_dodge.wav", pitch_sweep(900.0, 1700.0, 0.12, volume=0.22))
    write_wav("sfx_pickup_xp.wav", concat(
        tone(NOTE_FREQS["E5"], 0.05, volume=0.3, wave_shape="triangle"),
        tone(NOTE_FREQS["A5"], 0.07, volume=0.3, wave_shape="triangle"),
    ))
    write_wav("sfx_pickup_money.wav", concat(
        tone(NOTE_FREQS["A4"], 0.05, volume=0.32, wave_shape="square"),
        tone(NOTE_FREQS["E5"], 0.09, volume=0.32, wave_shape="square"),
    ))
    write_wav("sfx_level_up.wav", concat(
        tone(NOTE_FREQS["C4"], 0.1, volume=0.3, wave_shape="triangle"),
        tone(NOTE_FREQS["E4"], 0.1, volume=0.3, wave_shape="triangle"),
        tone(NOTE_FREQS["G4"], 0.1, volume=0.32, wave_shape="triangle"),
        tone(NOTE_FREQS["C5"], 0.26, volume=0.36, wave_shape="triangle", release=0.2),
    ))


def build_music_loop(name, chord_roots, bass_notes, beat=0.42, volume=0.16, lead_shape="triangle"):
    bars = len(chord_roots)
    loop = silence(bars * 4 * beat)
    for bar_index in range(bars):
        bar_start = bar_index * 4 * beat
        root = NOTE_FREQS[chord_roots[bar_index]]
        bass = NOTE_FREQS[bass_notes[bar_index]]
        arpeggio = [root, root * 1.1892, root * 1.4983, root * 2.0]  # minor arpeggio ratios
        for step in range(4):
            overlay_at(loop, tone(arpeggio[step], beat * 0.92, volume=volume, wave_shape=lead_shape, release=beat * 0.5), bar_start + step * beat)
            overlay_at(loop, tone(bass, beat * 0.95, volume=volume * 0.9, wave_shape="sine", release=beat * 0.4), bar_start + step * beat)
    write_wav(name, loop)


def build_music():
    build_music_loop(
        "music_combat.wav",
        chord_roots=["A3", "A3", "F3", "G3", "A3", "A3", "C4", "E3"],
        bass_notes=["A2", "A2", "F3", "G3", "A2", "A2", "C3", "E3"],
        beat=0.30, volume=0.14, lead_shape="square",
    )
    build_music_loop(
        "music_menu.wav",
        chord_roots=["A3", "F3", "C4", "G3"],
        bass_notes=["A2", "F3", "C3", "G3"],
        beat=0.62, volume=0.12, lead_shape="triangle",
    )


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    build_sfx()
    build_music()


if __name__ == "__main__":
    main()
