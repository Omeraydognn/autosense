# ADR 0001: Firebase Auth (guest + email) and Firestore in the EU

## Context
AutoSense needs sign-in, cloud sync with an offline cache, and a backend a four-person team can run without servers. Users handle personal data (vehicle, photos, audio), so the data region matters for KVKK. Requiring an account before first use would add friction.

## AI prompt
TODO (team): paste the real prompt you gave the AI assistant about the backend choice.

## AI result
TODO (team): summarise what the assistant suggested.

## Rejected suggestion
TODO (team): one suggestion you did not accept and why.

## Decision
- Firebase Authentication with guest (anonymous) sign-in plus email/password; linking a guest to an email keeps the same UID.
- Cloud Firestore in `europe-west1`, with offline cache and a synced list notifier (`core/storage/synced_list_notifier.dart`).
- Consent is stored as a snapshot on `users/{uid}` plus an append-only `consentLog`.

## Verification
- Live check: guest sign-in, consent log, vehicle and report sync, read back on the server side.
- Email linking, sign-out and sign-in verified on the Firebase Auth emulator.
