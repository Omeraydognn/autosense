"""Track A experiment runner.

    .venv/bin/python -m autosense_ml.run            # full pipeline
    .venv/bin/python -m autosense_ml.run --quick    # 1 seed, for smoke tests

Outputs (ml/reports/):
    track_a_results.json   machine-readable metrics (feeds MODEL_CARD.md)
    track_a_report.md      human-readable tables
    confusion_*.png        confusion matrices
"""

from __future__ import annotations

import argparse
import json
import time
import zlib
from dataclasses import asdict
from pathlib import Path

import joblib
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from . import data
from .audio import load, mix_at_snr
from .evaluation import SEEDS, mean_ci, paired_difference, run_protocol
from .features import YamnetEmbedder, mfcc_stats
from .grouping import group_by_source, ltas
from .labels import LABELS, classes_for_state
from .noise import NoiseBank, esc50_available

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
CACHE = data.CACHE
TEST_SNR_DB = 5.0
TRAIN_SNR_RANGE = (0.0, 20.0)
AUG_COPIES = 2
GROUP_THRESHOLD = 0.02  # cosine distance on LTAS; see grouping report


def cached(name: str, fn):
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{name}.joblib"
    if path.exists():
        return joblib.load(path)
    t = time.time()
    value = fn()
    joblib.dump(value, path)
    print(f"  cached {name} ({time.time() - t:.0f}s)")
    return value


def linear_head(c: float = 1.0):
    return make_pipeline(StandardScaler(), LogisticRegression(C=c, max_iter=3000))


def restrict_to_state(proba: np.ndarray, classes: np.ndarray, states: np.ndarray) -> np.ndarray:
    """App behaviour: the user picks the recording state, so only that state's
    classes are eligible. Returns argmax labels under that mask."""
    out = []
    for p, s in zip(proba, states):
        allowed = np.isin(classes, classes_for_state(s))
        out.append(classes[np.argmax(np.where(allowed, p, -1))])
    return np.array(out)


def main(quick: bool = False) -> dict:
    seeds = SEEDS[:1] if quick else SEEDS
    REPORTS.mkdir(parents=True, exist_ok=True)

    print("1/6 dataset")
    data.download()
    df = cached("index", data.build_index)
    y = df.label.to_numpy()
    states = df.state.to_numpy()
    audio = cached("audio", lambda: [load(p) for p in df.path])

    print("2/6 source groups")
    profiles = cached("ltas", lambda: np.stack([ltas(a) for a in audio]))
    groups, greport = group_by_source(profiles, y, GROUP_THRESHOLD)
    print(f"  {greport.n_groups} groups from {greport.n_clips} clips (largest {greport.largest_group})")

    print("3/6 noise bank:", "ESC-50" if esc50_available() else "colored-noise fallback")
    bank = NoiseBank()

    def noisy_versions(tag: str, split: str, snr, copies: int = 1):
        def build():
            rng = np.random.default_rng(zlib.crc32(tag.encode()))  # stable across runs
            out = []
            for _ in range(copies):
                row = []
                for a in audio:
                    s = snr if np.isscalar(snr) else rng.uniform(*snr)
                    row.append(mix_at_snr(a, bank.sample(rng, split), s, rng))
                out.append(row)
            return out

        return build

    print("4/6 features")
    mfcc = cached("mfcc", lambda: np.stack([mfcc_stats(a) for a in audio]))
    embedder = None

    def yam(clips):
        nonlocal embedder
        embedder = embedder or YamnetEmbedder()
        return np.stack([embedder(a) for a in clips])

    yam_clean = cached("yamnet_clean", lambda: yam(audio))
    noisy_test = {}
    for seed in seeds:
        clips = cached(f"noisy_test_audio_s{seed}", noisy_versions(f"test{seed}", "test", TEST_SNR_DB))[0]
        noisy_test[seed] = {
            "mfcc": cached(f"mfcc_noisy_s{seed}", lambda c=clips: np.stack([mfcc_stats(a) for a in c])),
            "yamnet": cached(f"yamnet_noisy_s{seed}", lambda c=clips: yam(c)),
        }
    aug_audio = cached("train_aug_audio", noisy_versions("train", "train", TRAIN_SNR_RANGE, AUG_COPIES))
    yam_aug = cached("yamnet_train_aug", lambda: np.stack([yam(copy) for copy in aug_audio]))

    print("5/6 protocol")
    labels = list(LABELS)

    def make(features_clean, feature_key, aug=None, c=1.0, state_aware=False):
        def fit(tr, ytr):
            X = features_clean[tr]
            Y = ytr
            if aug is not None:
                X = np.vstack([X, *[a[tr] for a in aug]])
                Y = np.concatenate([Y] + [ytr] * len(aug))
            return linear_head(c).fit(X, Y)

        def predict(model, X, te):
            if state_aware:
                return restrict_to_state(model.predict_proba(X), model.classes_, states[te])
            return model.predict(X)

        def clean(tr, ytr, te, seed):
            return predict(fit(tr, ytr), features_clean[te], te)

        def noisy(tr, ytr, te, seed):
            return predict(fit(tr, ytr), noisy_test[seed][feature_key][te], te)

        return clean, noisy

    runs = {}
    for name, feats, key, aug, c in [
        ("mfcc_logreg", mfcc, "mfcc", None, 1.0),
        ("yamnet_head", yam_clean, "yamnet", yam_aug, 0.5),
    ]:
        for state_aware in (False, True):
            tag = name + ("_state" if state_aware else "")
            clean, noisy = make(feats, key, aug, c, state_aware)
            t = time.time()
            runs[tag] = run_protocol(tag, y, groups, labels, clean, noisy, seeds=seeds)
            s = runs[tag].summary()
            print(f"  {tag:22s} macro-F1 {mean_ci(runs[tag].macro_f1)}  noisy gap {s['noise_gap_pp']['mean']:.1f} pp  ({time.time() - t:.0f}s)")

    diff = paired_difference(runs["yamnet_head"], runs["mfcc_logreg"])
    results = {
        "dataset": {
            "clips": int(len(df)),
            "per_class": df.label.value_counts().reindex(labels).astype(int).to_dict(),
            "seconds": {"min": float(df.seconds.min()), "median": float(df.seconds.median()), "max": float(df.seconds.max())},
            "excluded": "idle state/combined (synthetic multi-fault mixes)",
        },
        "grouping": asdict(greport),
        "protocol": {
            "cv": "StratifiedGroupKFold(5) by pseudo source recording",
            "seeds": list(seeds),
            "scores": len(seeds) * 5,
            "ci": "95% t-distribution",
            "noise": {"source": bank.source, "test_snr_db": TEST_SNR_DB, "train_aug_snr_db": TRAIN_SNR_RANGE, "train_aug_copies": AUG_COPIES},
        },
        "runs": {k: v.summary() for k, v in runs.items()},
        "yamnet_minus_baseline": diff.to_dict(),
    }
    keep = results["runs"]["yamnet_head"]["macro_f1"]
    base = results["runs"]["mfcc_logreg"]["macro_f1"]
    results["decision"] = {
        "p1_target_macro_f1": 0.70,
        "yamnet_meets_target": keep["mean"] >= 0.70,
        "yamnet_above_baseline_ci": keep["mean"] > base["high"],
        "paired_difference_positive": diff.low > 0,
        "noise_gap_within_10pp": results["runs"]["yamnet_head"]["noise_gap_pp"]["mean"] <= 10,
    }

    print("6/6 reports")
    (REPORTS / "track_a_results.json").write_text(json.dumps(results, indent=2))
    from .report import write_markdown, plot_confusions

    plot_confusions(runs, labels, REPORTS)
    write_markdown(results, REPORTS / "track_a_report.md")
    print(json.dumps(results["decision"], indent=2))
    return results


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    main(quick=ap.parse_args().quick)
