import re
from pathlib import Path

from autosense_ml.labels import CLASSES, LABELS, LABELS_WITH_UNKNOWN, classes_for_state

DART = Path(__file__).resolve().parents[2] / "app/lib/features/diagnosis/domain/audio_classes.dart"


def test_labels_match_flutter_app():
    src = DART.read_text()
    body = src[src.index("enum EngineSoundClass") :]
    dart = re.findall(r"^\s+\w+\('([a-z_]+)', '[^']*', (?:RecordingState\.(\w+)|null)", body, re.M)
    assert [d[0] for d in dart] == list(LABELS_WITH_UNKNOWN)
    assert {d[0]: d[1] for d in dart if d[1]} == {c.id: c.state for c in CLASSES}


def test_nine_classes_three_states():
    assert len(LABELS) == 9
    assert classes_for_state("idle") == ["normal_idle", "low_oil", "power_steering", "serpentine_belt"]
    assert len(classes_for_state("startup")) == 3
    assert len(classes_for_state("braking")) == 2
