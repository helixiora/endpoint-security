import 'dart:async';
import 'dart:io';

import '../models.dart';
import 'desktop_probe_parsers.dart';

class DesktopProbes {
  static Future<List<SecurityCheckResult>> run() async {
    if (Platform.isMacOS) {
      return _runMacOs();
    }
    if (Platform.isWindows) {
      return _runWindows();
    }
    if (Platform.isLinux) {
      return _runLinux();
    }
    return _unsupportedDesktopChecks();
  }

  static Future<List<SecurityCheckResult>> _runMacOs() async {
    final encryption = await _runCommand('/usr/bin/fdesetup', ['status']);
    final idle = await _runCommand(
      '/usr/bin/defaults',
      ['-currentHost', 'read', 'com.apple.screensaver', 'idleTime'],
    );
    final screenLockStatus = await _runCommand(
      '/usr/sbin/sysadminctl',
      ['-screenLock', 'status'],
    );
    final askForPassword = await _runCommand(
      '/usr/bin/defaults',
      ['read', 'com.apple.screensaver', 'askForPassword'],
    );
    final askForPasswordDelay = await _runCommand(
      '/usr/bin/defaults',
      ['read', 'com.apple.screensaver', 'askForPasswordDelay'],
    );
    final firewall = await _runCommand(
      '/usr/libexec/ApplicationFirewall/socketfilterfw',
      ['--getglobalstate'],
    );
    final onePasswordLocation = await _firstExistingPath([
      '/Applications/1Password.app',
      '/Applications/1Password 7.app',
      if (Platform.environment.containsKey('HOME'))
        '${Platform.environment['HOME']}/Applications/1Password.app',
      if (Platform.environment.containsKey('HOME'))
        '${Platform.environment['HOME']}/Applications/1Password 7.app',
    ]);

    return [
      DesktopProbeParsers.parseMacEncryption(
        stdout: encryption.stdout,
        stderr: encryption.stderr,
        exitCode: encryption.exitCode,
      ),
      DesktopProbeParsers.parseMacScreenLock(
        idleStdout: idle.stdout,
        screenLockStatusStdout: [
          screenLockStatus.stdout,
          screenLockStatus.stderr,
        ].where((value) => value.trim().isNotEmpty).join('\n'),
        askForPasswordStdout: askForPassword.stdout,
        askForPasswordDelayStdout: askForPasswordDelay.stdout,
        idleExitCode: idle.exitCode,
        screenLockStatusExitCode: screenLockStatus.exitCode,
        askForPasswordExitCode: askForPassword.exitCode,
        askForPasswordDelayExitCode: askForPasswordDelay.exitCode,
      ),
      DesktopProbeParsers.parseMacFirewall(
        stdout: firewall.stdout,
        stderr: firewall.stderr,
        exitCode: firewall.exitCode,
      ),
      DesktopProbeParsers.parseInstalledApp(
        id: 'one_password',
        label: '1Password installed',
        installed: onePasswordLocation != null,
        location: onePasswordLocation,
      ),
    ];
  }

  static Future<List<SecurityCheckResult>> _runWindows() async {
    final bitLocker = await _runCommand(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'''
$volume = Get-BitLockerVolume -MountPoint $env:SystemDrive |
  Select-Object MountPoint, ProtectionStatus, EncryptionMethod
$volume | ConvertTo-Json -Compress
''',
      ],
    );
    final screenSaver = await _runCommand(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'''
$key = 'HKCU:\Control Panel\Desktop'
[pscustomobject]@{
  Active = (Get-ItemProperty -Path $key -Name ScreenSaveActive -ErrorAction SilentlyContinue).ScreenSaveActive
  Secure = (Get-ItemProperty -Path $key -Name ScreenSaverIsSecure -ErrorAction SilentlyContinue).ScreenSaverIsSecure
  Timeout = (Get-ItemProperty -Path $key -Name ScreenSaveTimeOut -ErrorAction SilentlyContinue).ScreenSaveTimeOut
} | ConvertTo-Json -Compress
''',
      ],
    );
    final firewall = await _runCommand(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'''
Get-NetFirewallProfile |
  Select-Object Name, Enabled |
  ConvertTo-Json -Compress
''',
      ],
    );
    final onePassword = await _runCommand(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'''
$paths = @(
  "$Env:LOCALAPPDATA\1Password\app\8\1Password.exe",
  "$Env:ProgramFiles\1Password\app\8\1Password.exe",
  "$Env:ProgramFiles\1Password 7\1Password.exe"
)
$installed = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
[pscustomobject]@{
  Installed = [bool]$installed
  Path = $installed
} | ConvertTo-Json -Compress
''',
      ],
    );

    String? onePasswordPath;
    final onePasswordPayload = onePassword.stdout.trim();
    if (onePasswordPayload.isNotEmpty &&
        onePasswordPayload.contains('"Installed":true')) {
      final pathMatch =
          RegExp(r'"Path":"([^"]+)"').firstMatch(onePasswordPayload);
      onePasswordPath = pathMatch?.group(1);
    }

    return [
      DesktopProbeParsers.parseWindowsBitLocker(
        stdout: bitLocker.stdout,
        stderr: bitLocker.stderr,
        exitCode: bitLocker.exitCode,
      ),
      DesktopProbeParsers.parseWindowsScreenLock(
        stdout: screenSaver.stdout,
        stderr: screenSaver.stderr,
        exitCode: screenSaver.exitCode,
      ),
      DesktopProbeParsers.parseWindowsFirewall(
        stdout: firewall.stdout,
        stderr: firewall.stderr,
        exitCode: firewall.exitCode,
      ),
      DesktopProbeParsers.parseInstalledApp(
        id: 'one_password',
        label: '1Password installed',
        installed: onePasswordPath != null,
        location: onePasswordPath,
      ),
    ];
  }

  static Future<List<SecurityCheckResult>> _runLinux() async {
    final encryption = await _runCommand('findmnt', ['-no', 'SOURCE', '/']);
    final idle = await _runCommand(
      'gsettings',
      ['get', 'org.gnome.desktop.session', 'idle-delay'],
    );
    final lockEnabled = await _runCommand(
      'gsettings',
      ['get', 'org.gnome.desktop.screensaver', 'lock-enabled'],
    );
    final ufw = await _runCommand('ufw', ['status']);
    final firewallCmd = await _runCommand('firewall-cmd', ['--state']);
    final onePasswordLocation = await _firstExistingPath([
      '/opt/1Password/1password',
      '/usr/bin/1password',
      '/usr/share/1password/1password',
      '/snap/bin/1password',
    ]);

    return [
      DesktopProbeParsers.parseLinuxEncryption(
        stdout: encryption.stdout,
        stderr: encryption.stderr,
        exitCode: encryption.exitCode,
      ),
      DesktopProbeParsers.parseLinuxScreenLock(
        idleStdout: idle.stdout,
        lockEnabledStdout: lockEnabled.stdout,
        idleExitCode: idle.exitCode,
        lockEnabledExitCode: lockEnabled.exitCode,
      ),
      DesktopProbeParsers.parseLinuxFirewall(
        ufwStdout: ufw.stdout,
        ufwExitCode: ufw.exitCode,
        firewallCmdStdout: firewallCmd.stdout,
        firewallCmdExitCode: firewallCmd.exitCode,
      ),
      DesktopProbeParsers.parseInstalledApp(
        id: 'one_password',
        label: '1Password installed',
        installed: onePasswordLocation != null,
        location: onePasswordLocation,
      ),
    ];
  }

  static Future<List<SecurityCheckResult>> _unsupportedDesktopChecks() async {
    return const [
      SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary:
            'This desktop platform is not supported by the automatic probes.',
      ),
      SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary:
            'This desktop platform is not supported by the automatic probes.',
      ),
      SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary:
            'This desktop platform is not supported by the automatic probes.',
      ),
      SecurityCheckResult(
        id: 'one_password',
        label: '1Password installed',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary:
            'This desktop platform is not supported by the automatic probes.',
      ),
    ];
  }

  static Future<_CommandResult> _runCommand(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await Process.run(executable, arguments)
          .timeout(const Duration(seconds: 8));
      return _CommandResult(
        stdout: '${result.stdout}'.trim(),
        stderr: '${result.stderr}'.trim(),
        exitCode: result.exitCode,
      );
    } on TimeoutException {
      return const _CommandResult(
        stdout: '',
        stderr: 'Timed out while running probe.',
        exitCode: -1,
      );
    } on ProcessException catch (error) {
      return _CommandResult(
        stdout: '',
        stderr: error.message,
        exitCode: -1,
      );
    }
  }

  static Future<String?> _firstExistingPath(List<String> paths) async {
    for (final path in paths) {
      if (await FileSystemEntity.type(path) != FileSystemEntityType.notFound) {
        return path;
      }
    }
    return null;
  }
}

class _CommandResult {
  const _CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
}
