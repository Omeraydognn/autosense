"""Feature extractors: MFCC baseline and YAMNet embeddings."""

from __future__ import annotations

import librosa
import numpy as np

from .audio import SR

N_MFCC = 40


def mfcc_stats(y: np.ndarray, sr: int = SR) -> np.ndarray:
    """Baseline (P0 §4): 40 MFCCs plus their deltas, summarised by mean and
    standard deviation per clip → 160-d vector."""
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=N_MFCC, n_fft=1024, hop_length=320)
    delta = librosa.feature.delta(mfcc, width=9 if mfcc.shape[1] >= 9 else 3)
    feats = np.vstack([mfcc, delta])
    return np.concatenate([feats.mean(axis=1), feats.std(axis=1)]).astype(np.float32)


class YamnetEmbedder:
    """YAMNet (AudioSet, Gemmeke et al. 2017) frame embeddings, pooled per clip.

    YAMNet emits a 1024-d embedding every 0.48 s; a clip is summarised by the
    mean and standard deviation of its frames → 2048-d.
    """

    HANDLE = "https://tfhub.dev/google/yamnet/1"

    def __init__(self) -> None:
        import tensorflow_hub as hub  # heavy import, only when used

        self.model = hub.load(self.HANDLE)

    def frames(self, y: np.ndarray) -> np.ndarray:
        _scores, embeddings, _spec = self.model(y.astype(np.float32))
        return embeddings.numpy()

    def __call__(self, y: np.ndarray) -> np.ndarray:
        e = self.frames(y)
        return np.concatenate([e.mean(axis=0), e.std(axis=0)]).astype(np.float32)
