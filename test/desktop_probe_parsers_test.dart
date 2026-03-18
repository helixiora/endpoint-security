import 'package:endpoint_security_checkin/src/inspector/desktop_probe_parsers.dart';
import 'package:endpoint_security_checkin/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopProbeParsers', () {
    test('parses enabled FileVault status', () {
      final result = DesktopProbeParsers.parseMacEncryption(
        stdout: 'FileVault is On.',
        stderr: '',
        exitCode: 0,
      );

      expect(result.detectedStatus, CheckStatus.enabled);
      expect(result.detectedAutomatically, isTrue);
    });

    test('parses enabled macOS screen lock', () {
      final result = DesktopProbeParsers.parseMacScreenLock(
        idleStdout: '600',
        screenLockStatusStdout: 'screenLock delay is immediate',
        askForPasswordStdout: '1',
        askForPasswordDelayStdout: '0',
        idleExitCode: 0,
        screenLockStatusExitCode: 0,
        askForPasswordExitCode: 0,
        askForPasswordDelayExitCode: 0,
      );

      expect(result.detectedStatus, CheckStatus.enabled);
    });

    test('parses partially enabled Windows firewall as manual review', () {
      final result = DesktopProbeParsers.parseWindowsFirewall(
        stdout:
            '[{"Name":"Domain","Enabled":true},{"Name":"Public","Enabled":false}]',
        stderr: '',
        exitCode: 0,
      );

      expect(result.detectedStatus, CheckStatus.manualReview);
    });

    test('parses Linux mapper path as encrypted', () {
      final result = DesktopProbeParsers.parseLinuxEncryption(
        stdout: '/dev/mapper/ubuntu--vg-root',
        stderr: '',
        exitCode: 0,
      );

      expect(result.detectedStatus, CheckStatus.enabled);
    });
  });
}
