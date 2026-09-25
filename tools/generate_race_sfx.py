"""Generate five original, deterministic arcade racing cues.

Requires NumPy. Run from any directory with:
    python tools/generate_race_sfx.py
"""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np


SAMPLE_RATE = 48_000
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "audio" / "generated"
RNG = np.random.default_rng(20260925)


def envelope(length: int, attack: float, release: float) -> np.ndarray:
    """Click-free attack and release, with time values in seconds."""
    env = np.ones(length, dtype=np.float64)
    attack_samples = min(length, max(1, round(attack * SAMPLE_RATE)))
    release_samples = min(length, max(1, round(release * SAMPLE_RATE)))
    env[:attack_samples] *= np.sin(
        np.linspace(0, np.pi / 2, attack_samples, endpoint=True)
    ) ** 2
    env[-release_samples:] *= np.cos(
        np.linspace(0, np.pi / 2, release_samples, endpoint=True)
    ) ** 2
    return env


def tone(
    audio: np.ndarray,
    start: float,
    duration: float,
    frequency: float,
    end_frequency: float | None = None,
    *,
    gain: float = 0.35,
    pan: float = 0.0,
    brightness: float = 0.45,
    attack: float = 0.008,
    release: float = 0.13,
) -> None:
    """Layer a phase-continuous swept electronic tone into a stereo buffer."""
    first = round(start * SAMPLE_RATE)
    count = min(round(duration * SAMPLE_RATE), len(audio) - first)
    if count <= 0:
        return
    t = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    final = frequency if end_frequency is None else end_frequency
    phase = 2 * np.pi * (frequency * t + (final - frequency) * t * t / (2 * duration))
    # The shared timbre is mostly triangle-like, with restrained upper partials.
    signal = (
        np.sin(phase)
        + brightness * 0.23 * np.sin(2 * phase)
        + brightness * 0.16 * np.sin(3 * phase)
        + brightness * 0.07 * np.sin(5 * phase)
    )
    env = envelope(count, attack, release)
    env *= np.exp(-1.5 * t / duration)
    signal *= gain * env
    # Equal-power panning keeps the same perceived weight across the stereo field.
    angle = (pan + 1) * np.pi / 4
    audio[first : first + count, 0] += signal * np.cos(angle)
    audio[first : first + count, 1] += signal * np.sin(angle)


def noise_sweep(
    audio: np.ndarray, start: float, duration: float, gain: float, rising: bool
) -> None:
    """Add a quiet, filtered noise accent without any external samples."""
    first = round(start * SAMPLE_RATE)
    count = min(round(duration * SAMPLE_RATE), len(audio) - first)
    if count <= 0:
        return
    raw = RNG.standard_normal(count)
    smooth = np.convolve(raw, np.ones(13) / 13, mode="same")
    high = raw - smooth
    shape = np.linspace(0, 1, count)
    shape = shape if rising else 1 - shape
    signal = gain * high * envelope(count, 0.006, 0.04) * shape
    audio[first : first + count, 0] += signal * 0.7
    audio[first : first + count, 1] += signal * 0.7


def short_delay(audio: np.ndarray, delay_ms: float = 73, gain: float = 0.12) -> None:
    offset = round(delay_ms * SAMPLE_RATE / 1000)
    original = audio.copy()
    audio[offset:, 0] += gain * original[:-offset, 1]
    audio[offset:, 1] += gain * original[:-offset, 0]


def make_go() -> np.ndarray:
    audio = np.zeros((round(0.54 * SAMPLE_RATE), 2), dtype=np.float64)
    tone(audio, 0.00, 0.35, 440, 880, gain=0.45, release=0.08, brightness=0.8)
    tone(audio, 0.22, 0.27, 880, 1175, gain=0.41, release=0.15, brightness=0.85)
    tone(audio, 0.30, 0.21, 1320, gain=0.18, release=0.15, brightness=0.5)
    noise_sweep(audio, 0.00, 0.28, 0.045, rising=True)
    short_delay(audio, 55, 0.09)
    return audio


def make_lap_complete() -> np.ndarray:
    audio = np.zeros((round(0.73 * SAMPLE_RATE), 2), dtype=np.float64)
    for start, frequency, pan in ((0.00, 523.25, -0.22), (0.17, 659.25, 0.22), (0.34, 783.99, 0.0)):
        tone(audio, start, 0.28 if start < 0.34 else 0.36, frequency,
             gain=0.35, pan=pan, release=0.17, brightness=0.48)
    short_delay(audio, 76, 0.11)
    return audio


def make_final_lap() -> np.ndarray:
    audio = np.zeros((round(1.05 * SAMPLE_RATE), 2), dtype=np.float64)
    for start, pan in ((0.00, -0.17), (0.27, 0.17)):
        tone(audio, start, 0.22, 740, 800, gain=0.38, pan=pan,
             attack=0.004, release=0.07, brightness=0.65)
        tone(audio, start, 0.16, 1110, gain=0.12, pan=pan,
             attack=0.004, release=0.06, brightness=0.35)
    tone(audio, 0.56, 0.39, 880, 1175, gain=0.43,
         attack=0.007, release=0.18, brightness=0.68)
    noise_sweep(audio, 0.57, 0.22, 0.018, rising=True)
    short_delay(audio, 65, 0.09)
    return audio


def make_finish() -> np.ndarray:
    audio = np.zeros((round(1.55 * SAMPLE_RATE), 2), dtype=np.float64)
    notes = ((0.00, 523.25, -0.25), (0.17, 659.25, 0.18),
             (0.34, 783.99, -0.16), (0.51, 1046.50, 0.12))
    for index, (start, frequency, pan) in enumerate(notes):
        tone(audio, start, 0.30 if index < 3 else 0.74, frequency,
             gain=0.39 if index < 3 else 0.46, pan=pan,
             release=0.15 if index < 3 else 0.48, brightness=0.70)
    tone(audio, 0.52, 0.72, 1569.75, gain=0.15, pan=-0.12,
         release=0.47, brightness=0.42)
    noise_sweep(audio, 0.47, 0.20, 0.023, rising=True)
    short_delay(audio, 90, 0.13)
    return audio * 1.16


def make_dnf() -> np.ndarray:
    audio = np.zeros((round(0.94 * SAMPLE_RATE), 2), dtype=np.float64)
    for start, frequency, pan in ((0.00, 523.25, -0.12),
                                  (0.23, 440.00, 0.12),
                                  (0.46, 349.23, 0.0)):
        tone(audio, start, 0.26 if start < 0.46 else 0.40, frequency,
             gain=0.36, pan=pan, release=0.17, brightness=0.28)
    short_delay(audio, 78, 0.08)
    return audio


def write_wav(name: str, audio: np.ndarray) -> None:
    # Scale only downward, preserving the relative dynamics between events.
    peak = float(np.max(np.abs(audio)))
    if peak > 0.86:
        audio *= 0.86 / peak
    pcm = np.rint(np.clip(audio, -1.0, 1.0) * 32767).astype("<i2")
    path = OUTPUT_DIR / name
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())
    measured = pcm.astype(np.float64) / 32768
    print(
        f"{path}: duration={len(pcm) / SAMPLE_RATE:.3f}s, "
        f"sample_rate={SAMPLE_RATE}Hz, channels=2, "
        f"peak={np.max(np.abs(measured)):.4f}, "
        f"RMS={np.sqrt(np.mean(measured ** 2)):.4f}"
    )


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, generator in (
        ("go.wav", make_go),
        ("lap_complete.wav", make_lap_complete),
        ("final_lap.wav", make_final_lap),
        ("finish.wav", make_finish),
        ("dnf.wav", make_dnf),
    ):
        write_wav(name, generator())


if __name__ == "__main__":
    main()
