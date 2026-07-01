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

    test('parses macOS firewall states from socketfilterfw output', () {
      final enabled = DesktopProbeParsers.parseMacFirewall(
        stdout: 'Firewall is enabled. (State = 1)',
        stderr: '',
        exitCode: 0,
      );
      final disabled = DesktopProbeParsers.parseMacFirewall(
        stdout: 'Firewall is disabled. (State = 0)',
        stderr: '',
        exitCode: 0,
      );
      final unrelatedError = DesktopProbeParsers.parseMacFirewall(
        stdout: '',
        stderr: 'This feature could not be enabled: permission denied.',
        exitCode: 1,
      );

      expect(enabled.detectedStatus, CheckStatus.enabled);
      expect(disabled.detectedStatus, CheckStatus.disabled);
      expect(unrelatedError.detectedStatus, CheckStatus.unknown);
    });

    test('windows inactivity limit policy counts as screen lock', () {
      final result = DesktopProbeParsers.parseWindowsScreenLock(
        stdout:
            '{"Active":null,"Secure":null,"Timeout":null,"InactivityLimit":900}',
        stderr: '',
        exitCode: 0,
      );

      expect(result.detectedStatus, CheckStatus.enabled);
      expect(result.summary, contains('900'));
    });

    test('windows without screen saver or policy needs manual review', () {
      final result = DesktopProbeParsers.parseWindowsScreenLock(
        stdout:
            '{"Active":"0","Secure":"0","Timeout":"0","InactivityLimit":null}',
        stderr: '',
        exitCode: 0,
      );

      expect(result.detectedStatus, CheckStatus.manualReview);
      expect(result.requiresUserConfirmation, isTrue);
    });

    test('windows secure screen saver still counts as screen lock', () {
      final result = DesktopProbeParsers.parseWindowsScreenLock(
        stdout:
            '{"Active":"1","Secure":"1","Timeout":"600","InactivityLimit":null}',
        stderr: '',
        exitCode: 0,
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

    test('marks suspicious artifact scan as secure when no findings exist', () {
      final result = DesktopProbeParsers.parseSuspiciousArtifacts(
        findings: const [],
        scanCompleted: true,
      );

      expect(result.detectedStatus, CheckStatus.enabled);
      expect(result.detectedAutomatically, isTrue);
    });

    test('marks suspicious artifact scan as insecure when findings exist', () {
      final result = DesktopProbeParsers.parseSuspiciousArtifacts(
        findings: const ['/Applications/AnyDesk.app'],
        scanCompleted: true,
      );

      expect(result.detectedStatus, CheckStatus.disabled);
      expect(result.details, contains('/Applications/AnyDesk.app'));
    });

    test('marks endpoint protection as enabled when an agent is detected', () {
      final result = DesktopProbeParsers.parseEndpointProtection(
        findings: const ['Service edrsvc: Running'],
        scanCompleted: true,
      );

      expect(result.detectedStatus, CheckStatus.enabled);
      expect(result.details, contains('Service edrsvc: Running'));
    });

    test('marks missing endpoint protection for manual review', () {
      final result = DesktopProbeParsers.parseEndpointProtection(
        findings: const [],
        scanCompleted: true,
      );

      expect(result.detectedStatus, CheckStatus.manualReview);
      expect(result.detectedAutomatically, isTrue);
    });
  });
}
