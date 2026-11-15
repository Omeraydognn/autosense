"""Pseudo source-recording groups for clips without a vehicle ID (P0 §5).

The Kaggle clips are 2–10 s segments with no vehicle or recording ID.
Segments cut from the same recording share microphone, room and engine, so
their long-term average spectra (LTAS) are near-identical. We cluster LTAS
within each class and treat every cluster as one source: all its clips go to
the same CV fold. This is deliberately *conservative* — if two different cars
sound alike they are merged too, which can only make the test harder.

Exact and near-duplicate clips are always merged (distance below
`DUPLICATE_DISTANCE`).
"""

from __future__ import annotations

from dataclasses import dataclass

import librosa
import numpy as np
from scipy.cluster.hierarchy import fcluster, linkage
from scipy.spatial.distance import pdist, squareform

from .audio import SR

DUPLICATE_DISTANCE = 0.002


def ltas(y: np.ndarray, sr: int = SR, n_mels: int = 64) -> np.ndarray:
    """Long-term average log-mel spectrum, mean-removed (gain invariant)."""
    m = librosa.feature.melspectrogram(y=y, sr=sr, n_fft=1024, hop_length=512, n_mels=n_mels, fmax=sr / 2)
    v = np.log(m.mean(axis=1) + 1e-10)
    return (v - v.mean()).astype(np.float32)


@dataclass
class GroupingReport:
    threshold: float
    n_clips: int
    n_groups: int
    largest_group: int
    duplicates: int
    nn_distance_quantiles: dict


def group_by_source(
    profiles: np.ndarray,
    labels: np.ndarray,
    threshold: float,
) -> tuple[np.ndarray, GroupingReport]:
    """Average-linkage clustering on cosine distance of LTAS, per class.

    Returns global group ids (unique across classes) and a report.
    """
    groups = np.empty(len(labels), dtype=object)
    nn = []
    dups = 0
    for lab in np.unique(labels):
        idx = np.where(labels == lab)[0]
        if len(idx) == 1:
            groups[idx[0]] = f"{lab}:0"
            continue
        d = pdist(profiles[idx], metric="cosine")
        sq = squareform(d)
        np.fill_diagonal(sq, np.inf)
        nn.extend(sq.min(axis=1).tolist())
        dups += int((sq < DUPLICATE_DISTANCE).any(axis=1).sum())
        z = linkage(d, method="average")
        ids = fcluster(z, t=threshold, criterion="distance")
        for i, g in zip(idx, ids):
            groups[i] = f"{lab}:{g}"
    sizes = np.unique(groups, return_counts=True)[1]
    q = np.quantile(nn, [0.05, 0.25, 0.5, 0.75, 0.95]) if nn else np.zeros(5)
    report = GroupingReport(
        threshold=threshold,
        n_clips=len(labels),
        n_groups=len(sizes),
        largest_group=int(sizes.max()),
        duplicates=dups,
        nn_distance_quantiles={k: float(v) for k, v in zip(["p05", "p25", "p50", "p75", "p95"], q)},
    )
    return groups.astype(str), report
