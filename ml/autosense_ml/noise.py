"""Background-noise bank (ESC-50) for augmentation and robustness tests.

ESC-50 is used only for *mixing in* environmental noise and as negative
examples for the `unknown` class — never as engine data. Vehicle-like
categories are excluded so the noise cannot carry engine faults.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from .audio import colored_noise, load
from .data import RAW

ESC50 = RAW / "ESC-50-master"

# Realistic in/around-car interference for a phone held near an engine bay.
NOISE_CATEGORIES = (
    "wind", "rain", "pouring_water", "crackling_fire", "footsteps", "door_wood_knock",
    "keyboard_typing", "mouse_click", "breathing", "coughing", "sneezing", "laughing",
    "crying_baby", "dog", "birds", "chirping_birds", "crow", "insects", "thunderstorm",
    "clock_tick", "washing_machine", "vacuum_cleaner", "water_drops", "sea_waves",
)
# Never used: these overlap with the target domain.
EXCLUDED = ("engine", "car_horn", "train", "airplane", "helicopter", "chainsaw", "hand_saw", "siren")


def esc50_available() -> bool:
    return (ESC50 / "meta" / "esc50.csv").exists()


def esc50_meta() -> pd.DataFrame:
    meta = pd.read_csv(ESC50 / "meta" / "esc50.csv")
    meta = meta[~meta.category.isin(EXCLUDED)].copy()
    meta["path"] = [str(ESC50 / "audio" / f) for f in meta.filename]
    return meta


class NoiseBank:
    """Noise clips split by ESC-50 fold, so train-time augmentation and
    test-time robustness never share a noise recording."""

    def __init__(self, train_folds=(1, 2, 3), test_folds=(4, 5)) -> None:
        self.source = "esc50" if esc50_available() else "colored"
        self.train: list[np.ndarray] = []
        self.test: list[np.ndarray] = []
        if self.source == "esc50":
            meta = esc50_meta()
            meta = meta[meta.category.isin(NOISE_CATEGORIES)]
            for _, r in meta.iterrows():
                y = load(r.path, max_seconds=5)
                if np.max(np.abs(y)) < 1e-3:
                    continue
                (self.train if r.fold in train_folds else self.test).append(y)
        else:
            rng = np.random.default_rng(1234)
            for k in range(40):
                clip = colored_noise(16000 * 5, rng, exponent=1.0 + (k % 3) * 0.5)
                (self.train if k % 2 == 0 else self.test).append(clip)

    def sample(self, rng: np.random.Generator, split: str) -> np.ndarray:
        pool = self.train if split == "train" else self.test
        return pool[int(rng.integers(len(pool)))]


def unknown_examples(max_per_category: int = 8, seed: int = 0) -> tuple[list[Path], np.ndarray]:
    """Non-vehicle ESC-50 clips used as `unknown` training negatives.
    Returns paths and their ESC-50 fold (used as the CV group)."""
    meta = esc50_meta()
    rng = np.random.default_rng(seed)
    picked = meta.groupby("category", group_keys=False).apply(
        lambda d: d.sample(min(len(d), max_per_category), random_state=int(rng.integers(1 << 31)))
    )
    return [Path(p) for p in picked.path], picked.fold.to_numpy()
