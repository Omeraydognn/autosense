# ADR 0002: Owner-only Firestore rules, tested on the emulator

## Context
Firestore test mode lets anyone read and write. Each user's vehicles, reports and consent records must be private to that user.

## AI prompt
TODO (team): paste the real prompt you gave the AI assistant about security rules.

## AI result
TODO (team): summarise what the assistant suggested.

## Rejected suggestion
TODO (team): one suggestion you did not accept and why.

## Decision
- Data lives under the user's uid; `firestore.rules` allows access only to the authenticated owner. `storage.rules` follows the same idea.
- The consent log is append-only.
- Known debt: reports are client-written for now; a TODO in `firestore.rules` makes them server-only once the `diagnose()` function exists.

## Verification
- 17 security-rules tests on the Firebase emulator (`tests/rules`, `npm test`), also run in CI.
