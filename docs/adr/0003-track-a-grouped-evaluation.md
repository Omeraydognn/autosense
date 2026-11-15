# ADR 0003: Track A audio model: MFCC baseline vs YAMNet head, grouped evaluation

## Context
Track A classifies engine sounds into 9 classes. The Kaggle dataset has no vehicle ID, so a random train/test split would put near-duplicate segments of one recording on both sides and inflate the scores.

## AI prompt
TODO (team): paste the real prompt you gave the AI assistant about the evaluation design.

## AI result
TODO (team): summarise what the assistant suggested.

## Rejected suggestion
TODO (team): one suggestion you did not accept and why.

## Decision
- Compare a simple MFCC baseline with a YAMNet embedding plus a small trained head.
- Approximate source recordings by clustering clips on their long-term average spectrum (`ml/autosense_ml/grouping.py`) and run grouped cross-validation.
- 25 fold-seed evaluations per model; accept YAMNet only if macro-F1 >= 0.70, it beats the baseline's confidence interval, the paired difference is > 0 and the noise gap is <= 10 pp.
- Plan B: if YAMNet does not beat the baseline or macro-F1 < 0.60, ship the better model and reduce the task to normal vs abnormal.

## Verification
- 9 unit tests for the ML code pass. The real experiments are not run yet because the Kaggle API token is still missing (see `docs/PROGRESS.md`).
