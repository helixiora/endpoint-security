# Agent Instructions

## Repository Purpose

This repository is Helixiora Endpoint Security: a cross-platform Flutter app for
employee endpoint security attestation. The app collects device context and a
small endpoint posture snapshot, lets the employee review and correct it, then
submits a signed JSON envelope to a central endpoint such as the included Google
Apps Script / Google Sheets backend.

Treat this as an internal check-in and attestation tool, not an MDM, EDR, or
tamper-proof compliance system.

## Architecture Notes

- Flutter/Dart app code lives under `lib/`.
- Platform inspection is split between orchestration in
  `lib/src/inspector/endpoint_inspector.dart`, native adapters in
  `lib/src/inspector/native_inspection*.dart`, and desktop command/probe
  parsing in `lib/src/inspector/desktop_probes.dart` and
  `lib/src/inspector/desktop_probe_parsers.dart`.
- Submission signing is implemented in
  `lib/src/submission/submission_service.dart`.
- The reference backend is `backend/google-apps-script/Code.gs`; validate it
  with `scripts/check-apps-script.mjs`.
- Runtime build configuration is passed through Dart defines:
  `ORGANIZATION_NAME`, `APP_VERSION`, `SUBMISSION_ENDPOINT`, and
  `SUBMISSION_SECRET`.

## Product Boundaries

- Do not claim that mobile or web builds can automatically inspect host security
  controls. iOS, Android, and web use manual review for most checks by design.
- Preserve the employee review/correction step. Automatically detected values
  are useful input, not final authority.
- Keep the language clear about "attestation", "check-in", and "review"; avoid
  overstating this as enforcement or device management.
- The shared submission secret is embedded in distributed binaries. HMAC proves
  that a report came from a build with the secret, not from a specific employee
  or device. Web builds with a baked-in secret expose that secret to anyone who
  can load the JavaScript.

## Development Workflow

- Install dependencies with `make bootstrap`.
- Run the default local quality gate with `make check`.
- `make check` runs Dart format verification, Apps Script validation,
  `flutter analyze`, and `flutter test`.
- Use `dart format lib test` when touching Dart code.
- Add or update focused tests in `test/` for parser, model, submission, or UI
  behavior changes.
- Do not silently commit unrelated `pubspec.lock` solver churn. Keep lockfile
  changes only when dependency constraints or resolved versions are intentionally
  part of the change.

## GitHub and Release Conventions

- PR titles and commit subjects that may reach `main` must be
  Release Please-compatible Conventional Commit titles. Validate titles with
  `node scripts/check-pr-title.mjs "type(scope): subject"`.
- Use types supported by the validator: `feat`, `fix`, `perf`, `refactor`,
  `docs`, `test`, `build`, `ci`, `chore`, `revert`, and `style`.
- Release Please is configured with `release-type: dart` in
  `release-please-config.json`.
- App version strings for builds should come from `scripts/git-version.sh`
  unless a workflow explicitly supplies another value.

## Security and Backend Changes

- Preserve signed envelope schema v3: the client signs
  `signedAtUtc + "\n" + payloadJson` with HMAC-SHA256.
- Keep backend schema v2 compatibility unless there is a deliberate migration
  plan for already distributed apps.
- Backend changes must continue to reject stale timestamps, invalid signatures,
  and replayed signatures.
- Do not log or print submission secrets. Use placeholder values in docs and
  examples.
