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

## Why this shape

There is no clean portable API that lets a normal third-party app inspect all of these controls across desktop and mobile. This build uses automatic probes where the OS allows it and manual confirmation where it does not. That keeps the employee flow simple without pretending the mobile checks are more reliable than they are.

## Quick start

1. Install Flutter on a workstation that will build the app.
2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Set up the central submission endpoint. A Google Apps Script example is included in [`backend/google-apps-script/Code.gs`](backend/google-apps-script/Code.gs).
4. Run the app with your environment baked in:

   ```bash
   flutter run -d macos --dart-define=ORGANIZATION_NAME="Helixiora" --dart-define=SUBMISSION_ENDPOINT="https://script.google.com/macros/s/your-id/exec"
   ```

## Windows builds

Windows artifacts must be built on a Windows host.

### Local Windows build

From PowerShell on a Windows machine:

```powershell
./scripts/build-windows.ps1 -OrganizationName "Helixiora" -SubmissionEndpoint "https://script.google.com/macros/s/your-id/exec" -ZipArtifact
```

Output:

- Release folder: `build/windows/x64/runner/Release`
- Zip artifact: `build/windows/helixiora-endpoint-security-windows.zip`

### GitHub Actions build

A manual workflow is included in [`.github/workflows/windows-build.yml`](.github/workflows/windows-build.yml).

Recommended repository settings:

- Repository variable `ORGANIZATION_NAME`: `Helixiora`
- Repository secret `SUBMISSION_ENDPOINT`: your production submission URL

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

Open `Actions` -> `Build All Platforms` -> `Run workflow` to generate all artifacts in one run.

## Employee flow

1. Launch the app.
2. Review or fill in name, email, and endpoint name.
3. Review the detected security checks.
4. Override any check that needs manual correction.
5. Submit.

## Repository layout

- [`lib/main.dart`](lib/main.dart): app entry point
- [`lib/src/app.dart`](lib/src/app.dart): UI and review/submit flow
- [`lib/src/inspector/endpoint_inspector.dart`](lib/src/inspector/endpoint_inspector.dart): platform-aware inspection orchestration
- [`lib/src/inspector/desktop_probes.dart`](lib/src/inspector/desktop_probes.dart): desktop command execution
- [`backend/google-apps-script/Code.gs`](backend/google-apps-script/Code.gs): spreadsheet-backed webhook example

## Limitations

- The desktop app depends on local OS commands, so it is intended for normal internal distribution, not a locked-down app store sandbox.
- The macOS runner is intentionally not sandboxed, because the automatic checks rely on local system commands.
- Linux checks are heuristic because desktop environments and firewall stacks vary.
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
