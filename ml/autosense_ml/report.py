"""Markdown + figure reports for Track A."""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402


def _ci(d: dict, scale: float = 1.0, digits: int = 3) -> str:
    return f"{d['mean'] * scale:.{digits}f} ± {(d['high'] - d['low']) / 2 * scale:.{digits}f}"


def write_markdown(r: dict, path: Path) -> None:
    runs = r["runs"]
    L = []
    L.append("# Track A — evaluation report\n")
    L.append(f"Clips: **{r['dataset']['clips']}** (9 classes; {r['dataset']['excluded']} excluded).  ")
    g = r["grouping"]
    L.append(f"Pseudo source groups: **{g['n_groups']}** (LTAS cosine threshold {g['threshold']}, largest {g['largest_group']}, near-duplicates {g['duplicates']}).  ")
    p = r["protocol"]
    L.append(f"Protocol: {p['cv']}, seeds {p['seeds']} → {p['scores']} scores, {p['ci']} CI. Noise: {p['noise']['source']}, test at {p['noise']['test_snr_db']} dB SNR.\n")

    L.append("## Macro-F1 (mean ± 95% CI)\n")
    L.append("| Model | Clean | Noisy (5 dB) | Gap (pp) |")
    L.append("|---|---|---|---|")
    for k, v in runs.items():
        L.append(f"| `{k}` | {_ci(v['macro_f1'])} | {_ci(v['macro_f1_noisy'])} | {_ci(v['noise_gap_pp'], digits=1)} |")
    d = r["yamnet_minus_baseline"]
    L.append(f"\nPaired difference YAMNet − baseline (same 25 splits): **{_ci(d)}** (95% CI [{d['low']:.3f}, {d['high']:.3f}]).\n")

    L.append("`_state` rows restrict predictions to the classes of the recording state the user selected in the app (S3), which is how the model is used in production.\n")

    L.append("## Per-class F1 (mean ± 95% CI)\n")
    labels = list(runs["mfcc_logreg"]["per_class_f1"].keys())
    L.append("| Class | Baseline | YAMNet head |")
    L.append("|---|---|---|")
    for lab in labels:
        L.append(f"| {lab} | {_ci(runs['mfcc_logreg']['per_class_f1'][lab])} | {_ci(runs['yamnet_head']['per_class_f1'][lab])} |")

    L.append("\n## Decision (P1 targets)\n")
    for k, v in r["decision"].items():
        L.append(f"- {k}: **{v}**")
    L.append("\n![YAMNet confusion](confusion_yamnet_head.png)\n")
    path.write_text("\n".join(L) + "\n")


def plot_confusions(runs: dict, labels: list[str], out: Path) -> None:
    for name in ("mfcc_logreg", "yamnet_head"):
        cm = runs[name].confusion
        norm = cm / np.maximum(cm.sum(axis=1, keepdims=True), 1)
        fig, ax = plt.subplots(figsize=(7, 6))
        ax.imshow(norm, cmap="Blues", vmin=0, vmax=1)
        ax.set_xticks(range(len(labels)), labels, rotation=45, ha="right", fontsize=8)
        ax.set_yticks(range(len(labels)), labels, fontsize=8)
        for i in range(len(labels)):
            for j in range(len(labels)):
                ax.text(j, i, f"{norm[i, j]:.2f}", ha="center", va="center", fontsize=7,
                        color="white" if norm[i, j] > 0.5 else "black")
        ax.set_xlabel("Predicted")
        ax.set_ylabel("True")
        ax.set_title(f"{name} — row-normalised, summed over all folds")
        fig.tight_layout()
        fig.savefig(out / f"confusion_{name}.png", dpi=130)
        plt.close(fig)
