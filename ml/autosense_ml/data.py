"""Dataset download and indexing (Kaggle: malakragaie/car-diagnostics-dataset)."""

from __future__ import annotations

import re
import subprocess
import zipfile
from pathlib import Path

import pandas as pd
import soundfile as sf

from .labels import CLASSES, EXCLUDED_FOLDERS

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
CACHE = ROOT / "data" / "cache"
DATASET = "malakragaie/car-diagnostics-dataset"
DATASET_DIR = RAW / "car diagnostics dataset"


def download(force: bool = False) -> Path:
    """Downloads and unzips the dataset with the Kaggle CLI (needs
    ~/.kaggle/kaggle.json). Idempotent."""
    if DATASET_DIR.exists() and not force:
        return DATASET_DIR
    RAW.mkdir(parents=True, exist_ok=True)
    kaggle = Path(__file__).resolve().parents[1] / ".venv" / "bin" / "kaggle"
    cmd = [str(kaggle) if kaggle.exists() else "kaggle", "datasets", "download", "-d", DATASET, "-p", str(RAW)]
    subprocess.run(cmd, check=True)
    for z in RAW.glob("*.zip"):
        with zipfile.ZipFile(z) as f:
            f.extractall(RAW)
        z.unlink()
    if not DATASET_DIR.exists():
        raise FileNotFoundError(f"Expected {DATASET_DIR} after unzip")
    return DATASET_DIR


_NUM = re.compile(r"_(\d+)\.wav$", re.IGNORECASE)


def build_index(root: Path = DATASET_DIR) -> pd.DataFrame:
    """One row per single-label clip: path, label, state, clip number, duration."""
    rows = []
    for c in CLASSES:
        folder = root / c.folder
        if not folder.exists():
            raise FileNotFoundError(folder)
        for p in sorted(folder.glob("*.wav")):
            info = sf.info(str(p))
            m = _NUM.search(p.name)
            rows.append(
                {
                    "path": str(p),
                    "label": c.id,
                    "state": c.state,
                    "clip_no": int(m.group(1)) if m else -1,
                    "seconds": info.frames / info.samplerate,
                    "orig_sr": info.samplerate,
                    "channels": info.channels,
                }
            )
    df = pd.DataFrame(rows)
    assert not any(any(ex in p for ex in EXCLUDED_FOLDERS) for p in df.path)
    return df
