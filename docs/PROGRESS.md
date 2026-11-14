# AutoSense — progress & handoff

_Last updated: 14 Nov 2026 · branch `feature/p1-vertical-slice`_

This file says **what is done, how it was verified, and exactly where work stopped**, so anyone on the team can pick it up.

## Status at a glance

| Step | Area | Status |
|---|---|---|
| 1 | Repo skeleton, design system, screens S1–S5 (mock data) | ✅ Done |
| 2 | Firebase: Auth, Firestore sync, consent log, security rules | ✅ Done (Storage pending, see below) |
| 3 | Real capture: 16 kHz mic, speech suppression, photo anonymisation, upload policy | ✅ Done |
| 4 | **Track A: MFCC baseline + YAMNet head** | ⏸ **Code ready — blocked on Kaggle token** |
| 5 | Track B: RAG over manuals + Gemini vision + guardrails (server) | ⏳ Not started |
| 6 | Cloud Functions: `diagnose()`, `maintenanceCheck()` + FCM, 30-day retention | ⏳ Not started |
| 7 | Evaluation v1, MODEL_CARD.md, gold set incl. injection items | ⏳ Not started |

## ▶ Where we stopped (step 4)

Everything for Track A is written and unit-tested (`ml/`, 9 tests). The real experiments have **not been run yet** because the Kaggle dataset needs an API token.

To resume:

1. Put a Kaggle token in `~/.kaggle/` (kaggle.com → Settings → API):
   - new-style token text → `~/.kaggle/access_token`, or
   - legacy `kaggle.json` → `~/.kaggle/kaggle.json` (`chmod 600`).
2. Run the full pipeline (downloads data, groups clips, extracts features, runs 25 fold-seed evaluations for both models, writes reports):
   ```bash
   cd ml
   /opt/homebrew/bin/python3.11 -m venv .venv && .venv/bin/pip install -r requirements.txt   # first time only
   .venv/bin/python -m autosense_ml.run          # use --quick for a 1-seed smoke run
   ```
3. Read `ml/reports/track_a_report.md` and `track_a_results.json`. The `decision` block answers the P1 questions automatically (YAMNet ≥ 0.70 macro-F1, above baseline CI, paired difference > 0, noise gap ≤ 10 pp).

**Before trusting the numbers, check the grouping first.** Clips have no vehicle ID, so `grouping.py` clusters clips by their long-term average spectrum to approximate source recordings. `GROUP_THRESHOLD = 0.02` in `run.py` is a placeholder that has not been tuned yet. After the first run, look at `grouping.nn_distance_quantiles` in the results JSON, pick the threshold where near-duplicates/segments of one recording separate from different recordings, and re-run.

Still to do in step 4 after the first run:
- `unknown` class: train with ESC-50 negatives (`noise.unknown_examples`) + confidence threshold; report unknown recall and the rate of false "unknown" on car clips.
- Export: YAMNet + head → `engine_classifier.tflite` + `labels.json`; wire into the app (`tflite_flutter`), replacing the mock audio result in `MockDiagnosisService`.
- `docs/MODEL_CARD.md` v1 from the results JSON (intended use, out-of-scope, data, per-class results with CIs, limitations, advisory-only safety note).
- Plan B (P0 R1) if YAMNet does not beat the baseline CI or macro-F1 < 0.60: ship the better model, reduce to normal-vs-abnormal per state.

## What exists and how it was verified

### App (`app/`, Flutter 3.47, Riverpod 3, go_router)
- Screens S1–S5 + settings. Material 3 theme with Inter; light/dark; urgency colours U0–U3.
- **Verified:** `flutter analyze` clean, **47 tests** passing; manual end-to-end run in the browser (web build) and on an Android 16 emulator.
- Maintenance reminders (light track): `vehicle/domain/maintenance.dart`, tested.
- Guardrails: confident red telltale ⇒ U3; unknown citations dropped; urgency advice always derived from the *final* urgency (a bug found in emulator testing, now covered by a test).

### Firebase (project `autosense-team44`, Firestore in `europe-west1`)
- Auth: guest (anonymous) + email/password; guest → email linking keeps the UID.
- Firestore sync with offline cache (`core/storage/synced_list_notifier.dart`); consent snapshot on `users/{uid}` + append-only `consentLog`.
- Rules: `firestore.rules`, `storage.rules`. **Verified:** 17 emulator tests in `tests/rules` (`npm test`), also run in CI.
- **Verified live:** guest sign-in, consent log, vehicle + report sync (read back server-side). Email linking / sign-out / sign-in verified on the Auth emulator.

### Capture & privacy (`app/lib/features/capture/`)
- Mic: 16 kHz mono PCM, voice processing (AGC/NS/AEC) off. Silent-recording guard.
- Speech suppression: heuristic VAD (pitch-range autocorrelation + energy prominence), −20 dB. On synthetic signals: < 5 % false positives on engine-only audio, speech region −16.5 dB, ~26 ms per 10 s clip. **Not yet tested on real recorded speech.**
- Photo: EXIF/GPS stripped, orientation baked, faces (ML Kit) and plates (OCR + TR plate regex) pixelated + blurred, glare check. **Verified on Android** with a generated dashboard image containing a plate.
- Upload policy: photo only if the face/plate scan ran **and** diagnosis consent; audio only with model-improvement consent. Upload failure never blocks a report.

## Open items that need a person

| Item | Who | Why |
|---|---|---|
| Kaggle token in `~/.kaggle/` | AI Lead | Unblocks step 4 |
| Firebase **Blaze plan + Storage "Get started"** (EU location), then `firebase deploy --only storage` | Backend Lead / project owner | Media upload is implemented but Storage is not enabled |
| Register the Android App Check **debug token** before enforcing App Check | Backend Lead | Logged as "Failed to exchange debug token" on the emulator |
| **Rotate** the 3 Firebase API keys (they were pushed once and flagged by GitHub secret scanning), restrict the new ones (Android package / iOS bundle / web referrer), put them in `app/firebase.env.json`, then close the GitHub alerts as *revoked* | Project owner | Keys are now out of the repo and branch history, but the old ones were public for a while |
| iOS build on a Mac with Xcode + CocoaPods (`GoogleService-Info.plist` is present, options are in `firebase_options.dart`) | Frontend Lead | No Xcode on the machine used so far |
| Real-device test of the mic permission prompt and real speech suppression | Frontend / Quality | Emulator was installed with permissions pre-granted and a silent mic |
| Car Diagnostics Dataset licence shows **"Unknown"** on Kaggle | Quality Lead | Use stays academic and non-redistributed; ask the author if needed |

## Known limitations / debt
- `MockDiagnosisService` still produces the diagnosis (audio class, telltale, causes, citations). It is replaced by YAMNet (step 4) and `diagnose()` + RAG (steps 5–6).
- Maintenance intervals are generic; per-model values come from the manuals (step 5).
- Inter is fetched at runtime by `google_fonts`; bundle the font files to avoid a first-launch flash.
- PDF export on the checklist screen is a stub.
- Reports are client-written for now; `firestore.rules` has a TODO to make them server-only once `diagnose()` exists.
