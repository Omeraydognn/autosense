# AutoSense – Team Agreement

**Course:** Mobile Application Development
**Team:** 44
**Project:** AutoSense: AI-Powered Vehicle Audio & Dashboard Diagnostic Assistant
**Last updated:** 25 October 2026

## 1. Members and Roles

| Name | Student ID | GitHub | Role | Main responsibilities |
|---|---|---|---|---|
| Mert Buzluk | 2311051051 | @mertbuzluk | Quality Lead | Test plan, evaluation scripts and metrics, RAG gold set, KVKK checklist, user testing, code review standards |
| Ömer Aydoğan | 2311051013 | @Omeraydognn | AI Lead | Datasets, audio and dashboard models, TFLite export, prompts, RAG pipeline and guardrails, maintenance model |
| Furkan Kırbıyık | 2311051044 | @furkingham | Backend Lead | Firebase setup, Auth, Firestore schema and security rules, Cloud Storage, Cloud Functions, vector index |
| Erdal Helvacı | 2311051042 | @erdalhelvaci | Frontend Lead | Flutter architecture, screens and navigation, camera/microphone capture, on-device blurring, state management |

**Teaching assistants (collaborators):** @[TA1-username], @[TA2-username]

Roles define ownership, not limits. Every member contributes code and reviews other members' work.

## 2. Communication

- Main channel: [WhatsApp / Discord] group. Technical decisions are also written down as GitHub Issues or in the PR so they are traceable.
- Expected response time: within 24 hours on weekdays.
- Any member who expects to miss a deadline must tell the team at least 48 hours in advance.

## 3. Meetings

- Weekly sync: [day, time], about 30 minutes, online or on campus.
- Agenda: progress since last week, blockers, tasks for next week.
- The meeting owner rotates weekly and writes short notes in `docs/meetings/YYYY-MM-DD.md`.

## 4. Workflow and Git Rules

- Work is tracked on the GitHub Projects board. Each task is an Issue with an assignee and a milestone (P1, P2, …).
- `main` is protected. Nobody pushes directly to it.
- Branch naming: `feature/<short-name>`, `fix/<short-name>`, `docs/<short-name>`.
- Every change goes through a pull request linked to an Issue, with at least **one approving review** from another member.
- Commit messages are short and in English, in imperative form (e.g. `Add vehicle profile form`).
- API keys, service account files and other secrets are never committed. They go in `.env` or the Firebase config and are listed in `.gitignore`.

## 5. Definition of Done

A task is done when:
1. The code builds and runs without errors on Android.
2. The PR is reviewed and merged into `main`.
3. Related tests or evaluation results are added where applicable.
4. The README or docs are updated if behaviour or setup changed.

## 6. Decision Making

- Day-to-day technical decisions are made by the owner of that area.
- Decisions affecting more than one area (architecture, scope, deadlines) are discussed at the weekly meeting and decided by majority vote. If the vote is tied, the decision follows the evaluation results and the course requirements.

## 7. Workload and Accountability

- Work is distributed fairly across members and is visible through Issues, commits and PR reviews.
- If a member falls behind, the team first discusses it openly and redistributes tasks.
- If the problem continues after two weeks, the team informs the TAs.

## 8. Conflict Resolution

1. Discuss the issue directly and respectfully between the people involved.
2. If unresolved, bring it to the weekly meeting for a team decision.
3. If still unresolved, contact the TAs or the instructor.

## 9. Academic Integrity and AI Tool Use

- All submitted work follows the course's academic integrity policy.
- AI coding assistants may be used. Generated code must be reviewed, understood and tested by the member who commits it.
- External datasets, libraries and code snippets are credited in the README with their licence.

## 10. Agreement

By committing this file or approving its pull request, each member agrees to the terms above.

| Member | GitHub | Date |
|---|---|---|
| Mert Buzluk | @mertbuzluk | |
| Ömer Aydoğan | @Omeraydognn | |
| Furkan Kırbıyık | @furkingham | |
| Erdal Helvacı | @erdalhelvaci | |
