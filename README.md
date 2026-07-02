# Helixiora Endpoint Security

Branded Flutter app for employees to run on macOS, Windows, Linux, iOS, Android, and web. It collects a lightweight endpoint protection snapshot, lets the employee review it, and sends it to a central endpoint such as a Google Sheet-backed webhook.

## What it collects

- Owner name
- Owner email
- Endpoint name
- Hard disk encryption status
- Screensaver / screen lock status
- Firewall status
- Whether 1Password is installed

## Platform behavior

- macOS: automatic checks for FileVault, screen lock, firewall, and 1Password.
- Windows: automatic checks for BitLocker, screen saver lock, firewall, and 1Password.
- Linux: best-effort checks for disk encryption, GNOME screen lock, firewall, and 1Password. Linux reporting is conservative and may require manual review.
- iOS: device identity is collected, but security checks fall back to manual review because iOS does not expose these controls to regular apps.
- Android: device identity is collected, but security checks fall back to manual review in this first version for portability and policy simplicity.
- Web: browser identity is collected, and all security checks fall back to manual review because a browser app cannot inspect the host machine.

## Why this shape

There is no clean portable API that lets a normal third-party app inspect all of these controls across desktop and mobile. This build uses automatic probes where the OS allows it and manual confirmation where it does not. That keeps the employee flow simple without pretending the mobile checks are more reliable than they are.

## Quick start

1. Install Flutter on a workstation that will build the app.
2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Set up the central submission endpoint. A Google Apps Script example is included in [`backend/google-apps-script/Code.gs`](backend/google-apps-script/Code.gs) and documented in [`backend/google-apps-script/README.md`](backend/google-apps-script/README.md).
4. Run the app with your environment baked in:

   ```bash
   flutter run -d macos \
     --dart-define=ORGANIZATION_NAME="Helixiora" \
     --dart-define=APP_VERSION="$(./scripts/git-version.sh)" \
     --dart-define=SUBMISSION_ENDPOINT="https://script.google.com/macros/s/your-id/exec" \
     --dart-define=SUBMISSION_SECRET="shared-secret-from-apps-script-properties"
   ```

The app window title and the footer version badge use `APP_VERSION`. For tagged builds, the recommended value is `git describe --tags --always --dirty`, which [`scripts/git-version.sh`](scripts/git-version.sh) already wraps.

## Google Sheets backend

The included Apps Script flattens each submission into one spreadsheet column per JSON leaf using JSON pointer-style headers such as `/owner/name` and `/checks/0/detectedStatus`.

- New payload keys automatically create new columns in the header row.
- Array entries use numeric path segments.
- Keys containing `/` or `~` are escaped so column names stay stable.

See [`backend/google-apps-script/README.md`](backend/google-apps-script/README.md) for setup details.

## Developer workflow

1. Install dependencies:

   ```bash
   make bootstrap
   ```

2. Run the local quality gate:

   ```bash
   make check
   ```

3. Install the versioned Git pre-commit hook:

   ```bash
   make hooks-install
   ```

`make check` runs Dart format verification, the Apps Script verifier, `flutter analyze`, and `flutter test`.
It expects `flutter`, `dart`, and `node` to be available on your path.
If you use the Python `pre-commit` tool directly, `pre-commit install` and `pre-commit run` now work as well.

## Windows builds

Windows artifacts must be built on a Windows host.

### Local Windows build

From PowerShell on a Windows machine:

```powershell
./scripts/build-windows.ps1 -OrganizationName "Helixiora" -SubmissionEndpoint "https://script.google.com/macros/s/your-id/exec" -SubmissionSecret "shared-secret-from-apps-script-properties" -ZipArtifact
```

If `-AppVersion` is omitted, the script derives it from `git describe --tags --always --dirty`.

Output:

- Release folder: `build/windows/x64/runner/Release`
- Zip artifact: `build/windows/helixiora-endpoint-security-windows.zip`

### GitHub Actions build

A manual workflow is included in [`.github/workflows/windows-build.yml`](.github/workflows/windows-build.yml).

Recommended repository settings:

- Repository variable `ORGANIZATION_NAME`: `Helixiora`
- Repository secret `SUBMISSION_ENDPOINT`: your production submission URL
- Repository secret `SUBMISSION_SECRET`: the shared HMAC secret configured in Apps Script script properties

Then open `Actions` -> `Build Windows` -> `Run workflow`. The workflow builds the Windows release on `windows-latest` and uploads `helixiora-endpoint-security-windows.zip` as an artifact.

## Full CI build matrix

To build every supported target from GitHub Actions, use [`.github/workflows/build-all-platforms.yml`](.github/workflows/build-all-platforms.yml).

It runs:

- `flutter analyze`
- `flutter test`
- `flutter build web`
- `flutter build linux --release`
- `flutter build apk --release`
- `flutter build windows --release`
- `flutter build macos --release`
- `flutter build ios --release --no-codesign`

Each artifact build injects `APP_VERSION` from the checked-out git tags, so the generated app exposes the build version in the window title and the footer.

Artifacts uploaded by the workflow:

- `helixiora-web`
- `helixiora-linux`
- `helixiora-android-apk`
- `helixiora-windows`
- `helixiora-macos`
- `helixiora-ios-unsigned`

Recommended repository settings:

- Repository variable `ORGANIZATION_NAME`: `Helixiora`
- Repository secret `SUBMISSION_ENDPOINT`: your production submission URL
- Repository secret `SUBMISSION_SECRET`: the shared HMAC secret configured in Apps Script script properties
- Optional Android release signing secrets: `HELIXIORA_ANDROID_KEYSTORE_BASE64`, `HELIXIORA_ANDROID_KEYSTORE_PASSWORD`, `HELIXIORA_ANDROID_KEY_ALIAS`, and `HELIXIORA_ANDROID_KEY_PASSWORD`

Open `Actions` -> `Build All Platforms` -> `Run workflow` to generate all artifacts in one run.

### Releases

Pushing a tag that starts with `v` (for example `v1.2.0`) runs the same build matrix and attaches all platform artifacts as zip files to an automatically created GitHub release:

```bash
git tag v1.2.0
git push origin v1.2.0
```

If Android signing secrets are omitted, the Android release APK is built unsigned. Local Android release signing uses the same values as Gradle properties or environment variables, with `HELIXIORA_ANDROID_KEYSTORE` pointing at the `.jks` file.

## Maintenance automation

- [`.github/workflows/quality.yml`](.github/workflows/quality.yml): runs formatting, Apps Script validation, `flutter analyze`, and `flutter test` on pushes and pull requests.
- [`.github/workflows/pr-title.yml`](.github/workflows/pr-title.yml): checks pull request titles use Release Please-compatible Conventional Commit titles such as `feat:`, `fix:`, or `chore: release 1.2.3`.
- [`.github/dependabot.yml`](.github/dependabot.yml): keeps Flutter `pub` dependencies and GitHub Actions dependencies moving automatically.
- [`SECURITY.md`](SECURITY.md): documents private vulnerability reporting and supported-version expectations.
- [`.pre-commit-config.yaml`](.pre-commit-config.yaml): Python `pre-commit` configuration that runs the repository quality gate.
- [`.githooks/pre-commit`](.githooks/pre-commit): versioned fallback hook that defers to `pre-commit` when available.

## Employee flow

1. Launch the app.
2. Review or fill in name, email, and endpoint name.
3. Review the detected security checks.
4. Override any check that needs manual correction.
5. Submit.

## Repository layout

- [`lib/main.dart`](lib/main.dart): app entry point
- [`lib/src/app.dart`](lib/src/app.dart): check-in screen state and review/submit flow
- [`lib/src/widgets/`](lib/src/widgets): the UI building blocks (check cards, desktop layout, review dialog, form)
- [`lib/src/inspector/endpoint_inspector.dart`](lib/src/inspector/endpoint_inspector.dart): platform-aware inspection orchestration
- [`lib/src/inspector/desktop_probes.dart`](lib/src/inspector/desktop_probes.dart): desktop command execution
- [`backend/google-apps-script/Code.gs`](backend/google-apps-script/Code.gs): spreadsheet-backed webhook example
- [`scripts/check-apps-script.mjs`](scripts/check-apps-script.mjs): local verification for the Apps Script flattener

## Security model

- Submissions are signed with HMAC-SHA256 over the exact payload JSON string, using a shared secret baked into the build (`SUBMISSION_SECRET`) and verified by the Apps Script backend (envelope schema v3).
- The backend rejects envelopes older than 15 minutes and caches accepted signatures for 30 minutes, so captured requests cannot be replayed.
- The shared secret ships inside every distributed binary and is extractable by anyone with a copy of the app. The signature therefore proves a submission came from *a* build of this app, not from a specific employee or device. This is an attestation tool built on trust in employees, not tamper-proof evidence. If stronger provenance is ever needed, issue per-employee tokens out of band.
- Do not distribute the web build with a baked-in `SUBMISSION_SECRET` to an audience broader than the secret itself: in a web build the secret is plainly readable in the served JavaScript by anyone who can open the URL. Ship the web build secretless (employees use Copy JSON) or keep its URL as restricted as the secret.

## Limitations

- The desktop app depends on local OS commands, so it is intended for normal internal distribution, not a locked-down app store sandbox.
- The macOS runner is intentionally not sandboxed, because the automatic checks rely on local system commands.
- Linux checks are heuristic because desktop environments and firewall stacks vary.
- Windows screen-lock detection covers the legacy secure screen saver and the `InactivityTimeoutSecs` machine policy; sleep sign-in and dynamic lock cannot be read, so such setups fall back to employee confirmation.
- iOS and Android cannot fully self-inspect these settings without deeper MDM or enterprise integration.
- This is an attestation tool, not an enforcement tool. For stronger guarantees, pair it with MDM or endpoint management.

## Status

- `flutter analyze`: passes
- `flutter test`: passes
- `flutter build macos --debug`: passes
- `flutter build macos`: passes
- `flutter build web`: passes
- Android builds are currently blocked on this machine because the Android SDK `cmdline-tools` component is missing.
- iOS simulator builds are currently blocked on this machine because the iOS simulator runtime is not installed in Xcode.
- Windows builds require a Windows host. Local support is in [`scripts/build-windows.ps1`](scripts/build-windows.ps1) and CI support is in [`.github/workflows/windows-build.yml`](.github/workflows/windows-build.yml).
- Full multi-platform CI is in [`.github/workflows/build-all-platforms.yml`](.github/workflows/build-all-platforms.yml).
