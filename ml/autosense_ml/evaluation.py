"""Evaluation protocol (P0 §5).

* StratifiedGroupKFold, 5 folds, grouped by vehicle / source recording, so no
  source appears in both train and test.
* Repeated with 5 seeds → 25 fold-seed scores.
* Every metric reported as mean ± 95% CI (t-distribution, df = 24).
* Noise augmentation is applied to *test* folds only for the robustness
  metric; augmented copies are never used in a test fold of the clean run
  and never leak into training.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

import numpy as np
from scipy import stats
from sklearn.metrics import confusion_matrix, f1_score
from sklearn.model_selection import StratifiedGroupKFold

N_SPLITS = 5
SEEDS = (0, 1, 2, 3, 4)


@dataclass(frozen=True)
class CI:
    mean: float
    low: float
    high: float
    n: int

    @property
    def half_width(self) -> float:
        return (self.high - self.low) / 2

    def __str__(self) -> str:
        return f"{self.mean:.3f} ± {self.half_width:.3f}"

    def to_dict(self) -> dict:
        return {"mean": self.mean, "low": self.low, "high": self.high, "n": self.n}


def mean_ci(values, confidence: float = 0.95) -> CI:
    v = np.asarray(values, dtype=float)
    n = len(v)
    m = float(v.mean())
    if n < 2:
        return CI(m, m, m, n)
    se = float(v.std(ddof=1)) / np.sqrt(n)
    h = float(stats.t.ppf((1 + confidence) / 2, df=n - 1)) * se
    return CI(m, m - h, m + h, n)


def splits(y: np.ndarray, groups: np.ndarray, seeds=SEEDS, n_splits: int = N_SPLITS):
    """Yields (seed, fold, train_idx, test_idx) for every fold-seed pair."""
    for seed in seeds:
        sgkf = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=seed)
        for fold, (tr, te) in enumerate(sgkf.split(np.zeros(len(y)), y, groups)):
            assert not set(groups[tr]) & set(groups[te]), "group leakage"
            yield seed, fold, tr, te


@dataclass
class RunResult:
    name: str
    labels: list[str]
    macro_f1: list[float] = field(default_factory=list)
    per_class_f1: list[np.ndarray] = field(default_factory=list)
    macro_f1_noisy: list[float] = field(default_factory=list)
    confusion: np.ndarray | None = None

    def summary(self) -> dict:
        per_class = np.vstack(self.per_class_f1)
        out = {
            "name": self.name,
            "folds": len(self.macro_f1),
            "macro_f1": mean_ci(self.macro_f1).to_dict(),
            "per_class_f1": {lab: mean_ci(per_class[:, i]).to_dict() for i, lab in enumerate(self.labels)},
            "confusion": self.confusion.tolist() if self.confusion is not None else None,
        }
        if self.macro_f1_noisy:
            gap = np.asarray(self.macro_f1) - np.asarray(self.macro_f1_noisy)
            out["macro_f1_noisy"] = mean_ci(self.macro_f1_noisy).to_dict()
            out["noise_gap_pp"] = mean_ci(gap * 100).to_dict()
        return out


FitPredict = Callable[[np.ndarray, np.ndarray, np.ndarray, int], np.ndarray]
"""(train_idx, y_train, test_idx, seed) -> predicted labels for test_idx."""


def run_protocol(
    name: str,
    y: np.ndarray,
    groups: np.ndarray,
    labels: list[str],
    fit_predict: FitPredict,
    fit_predict_noisy: FitPredict | None = None,
    seeds=SEEDS,
) -> RunResult:
    """Runs the full grouped-CV protocol. `fit_predict_noisy` gets the same
    split and must evaluate on noise-mixed versions of the test clips."""
    res = RunResult(name=name, labels=list(labels))
    cm = np.zeros((len(labels), len(labels)), dtype=int)
    for seed, _fold, tr, te in splits(y, groups, seeds):
        pred = fit_predict(tr, y[tr], te, seed)
        res.macro_f1.append(f1_score(y[te], pred, labels=labels, average="macro", zero_division=0))
        res.per_class_f1.append(f1_score(y[te], pred, labels=labels, average=None, zero_division=0))
        cm += confusion_matrix(y[te], pred, labels=labels)
        if fit_predict_noisy is not None:
            pred_n = fit_predict_noisy(tr, y[tr], te, seed)
            res.macro_f1_noisy.append(f1_score(y[te], pred_n, labels=labels, average="macro", zero_division=0))
    res.confusion = cm
    return res


def paired_difference(a: RunResult, b: RunResult) -> CI:
    """Mean ± 95% CI of (a − b) macro-F1 over identical fold-seed splits."""
    assert len(a.macro_f1) == len(b.macro_f1)
    return mean_ci(np.asarray(a.macro_f1) - np.asarray(b.macro_f1))
