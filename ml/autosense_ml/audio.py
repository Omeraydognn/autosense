"""Audio I/O and noise mixing. Everything is 16 kHz mono float32, matching the app."""

from __future__ import annotations

from pathlib import Path

import librosa
import numpy as np

SR = 16_000
MAX_SECONDS = 10.0


def load(path: str | Path, sr: int = SR, max_seconds: float = MAX_SECONDS) -> np.ndarray:
    """Loads, downmixes and resamples a clip; trims to `max_seconds`."""
    y, _ = librosa.load(str(path), sr=sr, mono=True, duration=max_seconds)
    return y.astype(np.float32)


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(x), dtype=np.float64)) + 1e-12)


def mix_at_snr(signal: np.ndarray, noise: np.ndarray, snr_db: float, rng: np.random.Generator) -> np.ndarray:
    """Adds `noise` to `signal` at the given SNR (dB). Noise is looped/cropped
    to the signal length at a random offset. Output is peak-normalised only if
    it would clip."""
    if len(noise) < len(signal):
        noise = np.tile(noise, int(np.ceil(len(signal) / len(noise))))
    start = int(rng.integers(0, len(noise) - len(signal) + 1))
    n = noise[start : start + len(signal)]
    gain = rms(signal) / (rms(n) * 10 ** (snr_db / 20))
    out = signal + gain * n
    peak = float(np.max(np.abs(out)))
    return (out / peak * 0.99).astype(np.float32) if peak > 1 else out.astype(np.float32)


def colored_noise(n: int, rng: np.random.Generator, exponent: float = 1.0) -> np.ndarray:
    """1/f^exponent noise (1 = pink, 2 = brown/wind-like). Fallback noise bank
    when ESC-50 is not available."""
    white = rng.standard_normal(n)
    spectrum = np.fft.rfft(white)
    freqs = np.fft.rfftfreq(n)
    freqs[0] = freqs[1]
    spectrum /= freqs ** (exponent / 2)
    out = np.fft.irfft(spectrum, n)
    return (out / (np.max(np.abs(out)) + 1e-9)).astype(np.float32)
