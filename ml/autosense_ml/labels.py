"""Label space for Track A.

IDs are identical to `EngineSoundClass.id` in the Flutter app
(app/lib/features/diagnosis/domain/audio_classes.dart) so model outputs map
1:1 to the UI. `tests/test_labels.py` enforces this.
"""

from __future__ import annotations

from dataclasses import dataclass

UNKNOWN = "unknown"


@dataclass(frozen=True)
class SoundClass:
    id: str
    state: str  # idle | startup | braking
    folder: str  # folder name in the Kaggle dataset
    normal: bool = False


CLASSES: tuple[SoundClass, ...] = (
    SoundClass("normal_idle", "idle", "idle state/normal_engine_idle", normal=True),
    SoundClass("low_oil", "idle", "idle state/low_oil"),
    SoundClass("power_steering", "idle", "idle state/power_steering"),
    SoundClass("serpentine_belt", "idle", "idle state/serpentine_belt"),
    SoundClass("normal_startup", "startup", "startup state/normal_engine_startup", normal=True),
    SoundClass("bad_ignition", "startup", "startup state/bad_ignition"),
    SoundClass("dead_battery", "startup", "startup state/dead_battery"),
    SoundClass("normal_brakes", "braking", "braking state/normal_brakes", normal=True),
    SoundClass("worn_brakes", "braking", "braking state/worn_out_brakes"),
)

LABELS: tuple[str, ...] = tuple(c.id for c in CLASSES)
"""The nine labelled classes, in a fixed order (model output order)."""

LABELS_WITH_UNKNOWN: tuple[str, ...] = (*LABELS, UNKNOWN)

STATES: tuple[str, ...] = ("idle", "startup", "braking")

BY_ID = {c.id: c for c in CLASSES}

# Synthetic multi-fault mixes shipped with the dataset. Excluded from the
# 9-class task (they are not single labels); kept for later multi-label work.
EXCLUDED_FOLDERS = ("idle state/combined",)


def classes_for_state(state: str) -> list[str]:
    return [c.id for c in CLASSES if c.state == state]
