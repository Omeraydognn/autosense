import numpy as np
import pytest
from scipy import stats

from autosense_ml.evaluation import mean_ci, paired_difference, run_protocol, splits


def toy(n_groups=30, per_group=6, seed=0):
    rng = np.random.default_rng(seed)
    labels = np.array(["a", "b", "c"])
    g = np.repeat(np.arange(n_groups), per_group)
    y = labels[g % 3]
    return y, g, rng


def test_ci_matches_t_distribution():
    v = np.array([0.7, 0.72, 0.68, 0.75, 0.71])
    ci = mean_ci(v)
    h = stats.t.ppf(0.975, 4) * v.std(ddof=1) / np.sqrt(5)
    assert ci.mean == pytest.approx(v.mean())
    assert ci.half_width == pytest.approx(h)


def test_25_splits_and_no_group_leakage():
    y, g, _ = toy()
    out = list(splits(y, g))
    assert len(out) == 25
    for _seed, _fold, tr, te in out:
        assert not set(g[tr]) & set(g[te])
        assert set(y[te]) == {"a", "b", "c"}  # stratified


def test_seeds_change_the_split():
    y, g, _ = toy()
    a = [tuple(te) for s, f, tr, te in splits(y, g) if s == 0]
    b = [tuple(te) for s, f, tr, te in splits(y, g) if s == 1]
    assert a != b


def test_protocol_perfect_and_random_and_paired():
    y, g, rng = toy()
    labels = ["a", "b", "c"]
    perfect = run_protocol("p", y, g, labels, lambda tr, ytr, te, s: y[te])
    random = run_protocol("r", y, g, labels, lambda tr, ytr, te, s: rng.choice(labels, len(te)))
    assert perfect.summary()["macro_f1"]["mean"] == 1.0
    assert random.summary()["macro_f1"]["mean"] < 0.6
    d = paired_difference(perfect, random)
    assert d.low > 0.3


def test_noisy_gap_is_reported():
    y, g, _ = toy()
    r = run_protocol(
        "n", y, g, ["a", "b", "c"],
        lambda tr, ytr, te, s: y[te],
        fit_predict_noisy=lambda tr, ytr, te, s: np.where(np.arange(len(te)) % 2 == 0, y[te], "a"),
    )
    s = r.summary()
    assert s["noise_gap_pp"]["mean"] > 10
