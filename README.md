# AutoSense

AI-powered vehicle audio & dashboard diagnostic assistant — Team 20, Mobile Application Development.

> AutoSense is a **pre-diagnosis assistant**, not a replacement for a mechanic. Outputs are advisory only.

**Current status and next steps: [`docs/PROGRESS.md`](docs/PROGRESS.md).**

## P1 links

- CI (GitHub Actions): https://github.com/Omeraydognn/autosense/actions
- Architecture decision records: [`docs/adr/`](docs/adr/)
- Issues board: https://github.com/Omeraydognn/autosense/issues
- Team agreement: [`TEAM.md`](TEAM.md)
  
## Repository layout

| Path | Contents | Owner |
|------|----------|-------|
| `app/` | Flutter app (Android/iOS/web preview) — screens S1–S5, Riverpod, Firebase sync, on-device privacy | Frontend Lead |
| `ml/` | Track A — MFCC baseline, YAMNet head, grouped CV, reports | AI Lead |
| `firestore.rules`, `storage.rules`, `firebase.json` | Firebase security rules and config (project `autosense-team20`) | Backend Lead |
| `tests/rules/` | Security-rules tests on the Firebase emulator | Quality Lead |
| `functions/`, `rag/` | Cloud Functions and Track B RAG (not started) | Backend / AI Lead |
| `docs/` | Progress, manual licences, model card (soon) | Quality Lead |

## Getting started

```bash
# App (Firebase keys are not in the repo: copy app/firebase.env.example.json → app/firebase.env.json and fill it in)
cd app && flutter pub get && flutter test && flutter run --dart-define-from-file=firebase.env.json

# Security-rules tests (needs Java 21+ and firebase-tools)
cd tests/rules && npm ci && npm test

# Track A (Python 3.11)
cd ml && python3.11 -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/pytest
```

Run the app against local emulators: `firebase emulators:start --only auth,firestore,storage`, then
`flutter run --dart-define=USE_EMULATORS=true` (no keys needed). Without an API key the app falls back to local-only mode.

**Never commit Firebase config files.** `firebase.env.json`, `google-services.json`, `GoogleService-Info.plist` and `lib/firebase_options.dart` are git-ignored; non-secret IDs live in `app/lib/core/firebase/firebase_config.dart`.

CI (`.github/workflows/ci.yml`) runs `dart format`, `flutter analyze`, `flutter test` and the rules tests on every PR to `main`.

## Core flow

Vehicle Profile (S2) → Audio / Photo Capture (S3) → AI Diagnostic Report (S4) → Mechanic Checklist & History (S5)

Urgency levels: **U0** info · **U1** next service · **U2** within days · **U3** stop driving.

## Data, models and licences

| Resource | Use | Licence |
|---|---|---|
| [Car Diagnostics Dataset](https://www.kaggle.com/datasets/malakragaie/car-diagnostics-dataset) (Kaggle, malakragaie) | Track A training/evaluation, 9 single-label classes | Listed as *Unknown* on Kaggle — used for non-commercial academic work only, never redistributed in this repo |
| [ESC-50](https://github.com/karolpiczak/ESC-50) (Piczak, 2015) | Background-noise mixing and `unknown` negatives only | CC BY-NC 3.0 |
| [YAMNet](https://tfhub.dev/google/yamnet/1) (Gemmeke et al., 2017 / Google) | Audio embeddings | Apache 2.0 |
| Google ML Kit (face detection, text recognition) | On-device face/plate blurring | ML Kit Terms |
| Owner's manuals (6 models) | RAG corpus (planned) | See [`docs/MANUAL_LICENSES.md`](docs/MANUAL_LICENSES.md) |

Datasets are downloaded into `ml/data/raw/` (git-ignored).
