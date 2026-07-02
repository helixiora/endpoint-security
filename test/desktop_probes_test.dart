import 'package:endpoint_security_checkin/src/inspector/desktop_probes.dart';
import 'package:endpoint_security_checkin/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

ProbeCommandResult _ok(String stdout) =>
    ProbeCommandResult(stdout: stdout, stderr: '', exitCode: 0);

void main() {
  group('DesktopProbes Windows orchestration', () {
    test('decodes PowerShell JSON including backslash paths', () async {
      final probes = DesktopProbes(
        runCommand: (executable, arguments) async {
          expect(executable, 'powershell');
          final script = arguments.last;

          if (script.contains('Get-BitLockerVolume')) {
            return _ok(
              '{"MountPoint":"C:","ProtectionStatus":1,"EncryptionMethod":"XtsAes128"}',
            );
          }
          if (script.contains('ScreenSaveActive')) {
            return _ok(
              '{"Active":null,"Secure":null,"Timeout":null,"InactivityLimit":900}',
            );
          }
          if (script.contains('Get-NetFirewallProfile')) {
            return _ok(
              '[{"Name":"Domain","Enabled":true},{"Name":"Public","Enabled":true}]',
            );
          }
          if (script.contains('1Password')) {
            return _ok(
              r'{"Installed":true,"Path":"C:\\Users\\jane\\AppData\\Local\\1Password\\app\\8\\1Password.exe"}',
            );
          }
          if (script.contains('AnyDesk')) {
            // ConvertTo-Json emits a bare string for a single finding.
            return _ok(r'"C:\\Program Files\\AnyDesk\\AnyDesk.exe"');
          }
          if (script.contains(r'$indicators')) {
            return _ok(
              '["Service WinDefend: Running","Security Center product Microsoft Defender"]',
            );
          }
          fail('Unexpected PowerShell script: $script');
        },
        pathExists: (path) async => false,
        environment: const {},
      );

      final checks = await probes.runWindowsProbes();
      final byId = {for (final check in checks) check.id: check};

      expect(byId['disk_encryption']!.detectedStatus, CheckStatus.enabled);
      expect(byId['screen_lock']!.detectedStatus, CheckStatus.enabled);
      expect(byId['firewall']!.detectedStatus, CheckStatus.enabled);

      final onePassword = byId['one_password']!;
      expect(onePassword.detectedStatus, CheckStatus.enabled);
      expect(
        onePassword.details,
        contains(
          r'C:\Users\jane\AppData\Local\1Password\app\8\1Password.exe',
        ),
      );

      final suspicious = byId['suspicious_artifacts']!;
      expect(suspicious.detectedStatus, CheckStatus.disabled);
      expect(
        suspicious.details,
        contains(r'C:\Program Files\AnyDesk\AnyDesk.exe'),
      );

      final protection = byId['endpoint_protection']!;
      expect(protection.detectedStatus, CheckStatus.enabled);
      expect(protection.details, contains('Service WinDefend: Running'));
    });

    test('treats failed scans as manual review', () async {
      final probes = DesktopProbes(
        runCommand: (executable, arguments) async => const ProbeCommandResult(
          stdout: '',
          stderr: 'powershell blew up',
          exitCode: -1,
        ),
        pathExists: (path) async => false,
        environment: const {},
      );

      final checks = await probes.runWindowsProbes();
      final byId = {for (final check in checks) check.id: check};

      expect(
        byId['suspicious_artifacts']!.detectedStatus,
        CheckStatus.manualReview,
      );
      expect(
        byId['endpoint_protection']!.detectedStatus,
        CheckStatus.manualReview,
      );
      expect(byId['one_password']!.detectedStatus, CheckStatus.disabled);
    });
  });

  group('DesktopProbes macOS orchestration', () {
    test('wires command output and path findings into checks', () async {
      final probes = DesktopProbes(
        runCommand: (executable, arguments) async {
          if (executable == '/usr/bin/fdesetup') {
            return _ok('FileVault is On.');
          }
          if (executable == '/usr/bin/defaults' &&
              arguments.contains('idleTime')) {
            return _ok('600');
          }
          if (executable == '/usr/sbin/sysadminctl') {
            return _ok('screenLock delay is immediate');
          }
          if (executable == '/usr/bin/defaults' &&
              arguments.contains('askForPassword')) {
            return _ok('1');
          }
          if (executable == '/usr/bin/defaults' &&
              arguments.contains('askForPasswordDelay')) {
            return _ok('0');
          }
          if (executable == '/usr/libexec/ApplicationFirewall/socketfilterfw') {
            return _ok('Firewall is enabled. (State = 1)');
          }
          fail('Unexpected command: $executable $arguments');
        },
        pathExists: (path) async =>
            path == '/Applications/1Password.app' ||
            path == '/usr/local/bin/ngrok',
        environment: const {'HOME': '/Users/jane'},
      );

      final checks = await probes.runMacOsProbes();
      final byId = {for (final check in checks) check.id: check};

      expect(byId['disk_encryption']!.detectedStatus, CheckStatus.enabled);
      expect(byId['screen_lock']!.detectedStatus, CheckStatus.enabled);
      expect(byId['firewall']!.detectedStatus, CheckStatus.enabled);
      expect(byId['one_password']!.detectedStatus, CheckStatus.enabled);
      expect(
        byId['one_password']!.details,
        contains('/Applications/1Password.app'),
      );

      final suspicious = byId['suspicious_artifacts']!;
      expect(suspicious.detectedStatus, CheckStatus.disabled);
      expect(suspicious.details, contains('/usr/local/bin/ngrok'));

      expect(
        byId['endpoint_protection']!.detectedStatus,
        CheckStatus.manualReview,
      );
    });
  });
}
