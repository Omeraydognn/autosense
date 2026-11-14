import numpy as np
import pytest

from autosense_ml.audio import colored_noise, mix_at_snr, rms
from autosense_ml.features import mfcc_stats


def test_mix_at_snr_hits_target():
    rng = np.random.default_rng(0)
    sig = (0.3 * np.sin(2 * np.pi * 120 * np.arange(16000) / 16000)).astype(np.float32)
    noise = colored_noise(8000, rng)
    out = mix_at_snr(sig, noise, 5.0, rng)
    added = out - sig
    assert 20 * np.log10(rms(sig) / rms(added)) == pytest.approx(5.0, abs=0.1)
    assert len(out) == len(sig)


def test_mfcc_stats_shape():
    y = np.random.default_rng(1).standard_normal(16000 * 3).astype(np.float32) * 0.1
    f = mfcc_stats(y)
    assert f.shape == (160,)
    assert np.isfinite(f).all()
