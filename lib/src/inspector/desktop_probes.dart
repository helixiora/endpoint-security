import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'desktop_probe_parsers.dart';

class ProbeCommandResult {
  const ProbeCommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
}

typedef ProbeCommandRunner = Future<ProbeCommandResult> Function(
  String executable,
  List<String> arguments,
);

typedef ProbePathChecker = Future<bool> Function(String path);

class DesktopProbes {
  DesktopProbes({
    ProbeCommandRunner? runCommand,
    ProbePathChecker? pathExists,
    Map<String, String>? environment,
  })  : _runCommand = runCommand ?? _runProcess,
        _pathExists = pathExists ?? _fileSystemPathExists,
        _environmentOverride = environment;

  final ProbeCommandRunner _runCommand;
  final ProbePathChecker _pathExists;
  final Map<String, String>? _environmentOverride;

  // Resolved lazily so constructing DesktopProbes never touches dart:io
  // Platform, which throws on the web.
  Map<String, String> get _environment =>
      _environmentOverride ?? Platform.environment;

  Future<List<SecurityCheckResult>> run() async {
    if (Platform.isMacOS) {
      return runMacOsProbes();
    }
    if (Platform.isWindows) {
      return runWindowsProbes();
    }
    if (Platform.isLinux) {
      return runLinuxProbes();
    }
    return _unsupportedDesktopChecks();
  }

  @visibleForTesting
  Future<List<SecurityCheckResult>> runMacOsProbes() async {
    final home = _environment['HOME'];

    // The probes are independent, so they run concurrently to keep the
    // inspection fast even when individual commands are slow.
    final encryptionFuture = _runCommand('/usr/bin/fdesetup', ['status']);
    final idleFuture = _runCommand(
      '/usr/bin/defaults',
      ['-currentHost', 'read', 'com.apple.screensaver', 'idleTime'],
    );
    final screenLockStatusFuture = _runCommand(
      '/usr/sbin/sysadminctl',
      ['-screenLock', 'status'],
    );
    final askForPasswordFuture = _runCommand(
      '/usr/bin/defaults',
      ['read', 'com.apple.screensaver', 'askForPassword'],
    );
    final askForPasswordDelayFuture = _runCommand(
      '/usr/bin/defaults',
      ['read', 'com.apple.screensaver', 'askForPasswordDelay'],
    );
    final firewallFuture = _runCommand(
      '/usr/libexec/ApplicationFirewall/socketfilterfw',
      ['--getglobalstate'],
    );
    final onePasswordFuture = _firstExistingPath([
      '/Applications/1Password.app',
      '/Applications/1Password 7.app',
      if (home != null) '$home/Applications/1Password.app',
      if (home != null) '$home/Applications/1Password 7.app',
    ]);
    final suspiciousArtifactsFuture = _existingPaths([
      '/Applications/Advanced Mac Cleaner.app',
      '/Applications/AnyDesk.app',
      '/Applications/RustDesk.app',
      '/Applications/TeamViewer.app',
      '/Applications/UltraViewer.app',
      if (home != null) '$home/Applications/AnyDesk.app',
      if (home != null) '$home/Applications/RustDesk.app',
      if (home != null) '$home/Applications/TeamViewer.app',
      '/Library/LaunchAgents/com.anydesk.AnyDesk.plist',
      '/Library/LaunchDaemons/com.anydesk.AnyDesk.plist',
      '/Library/LaunchDaemons/com.teamviewer.Helper.plist',
      '/Library/PrivilegedHelperTools/com.teamviewer.Helper',
      '/usr/local/bin/ngrok',
      '/opt/homebrew/bin/ngrok',
      '/usr/local/bin/cloudflared',
      '/opt/homebrew/bin/cloudflared',
    ]);
    final endpointProtectionFuture = _existingPaths([
      '/Applications/Microsoft Defender.app',
      '/Applications/CrowdStrike Falcon.app',
      '/Applications/SentinelOne.app',
      '/Applications/Jamf Protect.app',
      '/Applications/Malwarebytes.app',
      '/Applications/Sophos Endpoint.app',
      '/Applications/VMware Carbon Black Cloud.app',
      '/Applications/OpenEDR.app',
      '/Library/LaunchDaemons/com.microsoft.fresno.plist',
      '/Library/LaunchDaemons/com.crowdstrike.falcond.plist',
      '/Library/LaunchDaemons/com.sentinelone.sentineld.plist',
      '/Library/LaunchDaemons/com.jamf.protect.daemon.plist',
      '/Library/LaunchDaemons/com.malwarebytes.mbam.rtprotection.daemon.plist',
      '/Library/LaunchDaemons/com.sophos.common.servicemanager.plist',
      '/Library/LaunchDaemons/com.vmware.carbonblack.cloud.plist',
      '/Library/CS/falcond',
      '/Library/Sentinel/sentinel-agent.bundle',
      '/usr/local/bin/mdatp',
      '/usr/local/bin/osqueryi',
    ]);

    final encryption = await encryptionFuture;
    final idle = await idleFuture;
    final screenLockStatus = await screenLockStatusFuture;
    final askForPassword = await askForPasswordFuture;
    final askForPasswordDelay = await askForPasswordDelayFuture;
    final firewall = await firewallFuture;
    final onePasswordLocation = await onePasswordFuture;
    final suspiciousArtifacts = await suspiciousArtifactsFuture;
    final endpointProtection = await endpointProtectionFuture;

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
      DesktopProbeParsers.parseSuspiciousArtifacts(
        findings: suspiciousArtifacts,
        scanCompleted: true,
      ),
      DesktopProbeParsers.parseEndpointProtection(
        findings: endpointProtection,
        scanCompleted: true,
      ),
    ];
  }

  @visibleForTesting
  Future<List<SecurityCheckResult>> runWindowsProbes() async {
    final bitLockerFuture = _runPowerShell(r'''
$volume = Get-BitLockerVolume -MountPoint $env:SystemDrive |
  Select-Object MountPoint, ProtectionStatus, EncryptionMethod
$volume | ConvertTo-Json -Compress
''');
    final screenSaverFuture = _runPowerShell(r'''
$key = 'HKCU:\Control Panel\Desktop'
$policyKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
[pscustomobject]@{
  Active = (Get-ItemProperty -Path $key -Name ScreenSaveActive -ErrorAction SilentlyContinue).ScreenSaveActive
  Secure = (Get-ItemProperty -Path $key -Name ScreenSaverIsSecure -ErrorAction SilentlyContinue).ScreenSaverIsSecure
  Timeout = (Get-ItemProperty -Path $key -Name ScreenSaveTimeOut -ErrorAction SilentlyContinue).ScreenSaveTimeOut
  InactivityLimit = (Get-ItemProperty -Path $policyKey -Name InactivityTimeoutSecs -ErrorAction SilentlyContinue).InactivityTimeoutSecs
} | ConvertTo-Json -Compress
''');
    final firewallFuture = _runPowerShell(r'''
Get-NetFirewallProfile |
  Select-Object Name, Enabled |
  ConvertTo-Json -Compress
''');
    final onePasswordFuture = _runPowerShell(r'''
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
''');
    final suspiciousArtifactsFuture = _runPowerShell(r'''
$paths = @(
  "$Env:LOCALAPPDATA\Programs\AnyDesk\AnyDesk.exe",
  "$Env:ProgramFiles\AnyDesk\AnyDesk.exe",
  "${Env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe",
  "$Env:ProgramFiles\TeamViewer\TeamViewer.exe",
  "${Env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe",
  "$Env:LOCALAPPDATA\Programs\RustDesk\rustdesk.exe",
  "$Env:ProgramFiles\RustDesk\rustdesk.exe",
  "$Env:ProgramFiles\UltraViewer\UltraViewer_Desktop.exe",
  "${Env:ProgramFiles(x86)}\UltraViewer\UltraViewer_Desktop.exe",
  "$Env:ProgramFiles\Google\Chrome Remote Desktop\CurrentVersion\remoting_host.exe",
  "${Env:ProgramFiles(x86)}\Google\Chrome Remote Desktop\CurrentVersion\remoting_host.exe",
  "$Env:LOCALAPPDATA\ngrok\ngrok.exe",
  "$Env:USERPROFILE\Downloads\ngrok.exe",
  "$Env:USERPROFILE\Downloads\cloudflared.exe"
)
$paths |
  Where-Object { $_ -and (Test-Path $_) } |
  ConvertTo-Json -Compress
''');
    final endpointProtectionFuture = _runPowerShell(r'''
$indicators = @()
$serviceNames = @(
  'edrsvc',
  'WinDefend',
  'Sense',
  'CSFalconService',
  'SentinelAgent',
  'MBAMService',
  'Sophos Endpoint Defense Service',
  'CbDefense',
  'osqueryd'
)
foreach ($serviceName in $serviceNames) {
  $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
  if ($service) {
    $indicators += "Service $($service.Name): $($service.Status)"
  }
}
$paths = @(
  "$Env:ProgramFiles\OpenEdr\EdrAgentV2",
  "$Env:ProgramData\edrsvc",
  "$Env:ProgramFiles\Microsoft Defender",
  "$Env:ProgramFiles\Windows Defender",
  "$Env:ProgramFiles\CrowdStrike",
  "$Env:ProgramFiles\SentinelOne",
  "$Env:ProgramFiles\Malwarebytes",
  "$Env:ProgramFiles\Sophos",
  "$Env:ProgramFiles\CarbonBlack",
  "$Env:ProgramFiles\osquery"
)
foreach ($path in $paths) {
  if ($path -and (Test-Path $path)) {
    $indicators += "Path $path"
  }
}
try {
  $products = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop
  foreach ($product in $products) {
    if ($product.displayName) {
      $indicators += "Security Center product $($product.displayName)"
    }
  }
} catch {}
$indicators | Select-Object -Unique | ConvertTo-Json -Compress
''');

    final bitLocker = await bitLockerFuture;
    final screenSaver = await screenSaverFuture;
    final firewall = await firewallFuture;
    final onePassword = await onePasswordFuture;
    final suspiciousArtifacts = await suspiciousArtifactsFuture;
    final endpointProtection = await endpointProtectionFuture;

    String? onePasswordPath;
    var onePasswordInstalled = false;
    final onePasswordPayload = _decodeJson(onePassword.stdout);
    if (onePasswordPayload is Map<String, dynamic>) {
      onePasswordInstalled = onePasswordPayload['Installed'] == true;
      final path = onePasswordPayload['Path'];
      if (path is String && path.trim().isNotEmpty) {
        onePasswordPath = path;
      }
    }
    final suspiciousFindings =
        _decodeJsonStringList(suspiciousArtifacts.stdout);
    final endpointProtectionFindings =
        _decodeJsonStringList(endpointProtection.stdout);

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
        installed: onePasswordInstalled,
        location: onePasswordPath,
      ),
      DesktopProbeParsers.parseSuspiciousArtifacts(
        findings: suspiciousFindings,
        scanCompleted: suspiciousArtifacts.exitCode == 0,
        failureDetails: suspiciousArtifacts.stderr,
      ),
      DesktopProbeParsers.parseEndpointProtection(
        findings: endpointProtectionFindings,
        scanCompleted: endpointProtection.exitCode == 0,
        failureDetails: endpointProtection.stderr,
      ),
    ];
  }

  @visibleForTesting
  Future<List<SecurityCheckResult>> runLinuxProbes() async {
    final encryptionFuture = _runCommand('findmnt', ['-no', 'SOURCE', '/']);
    final idleFuture = _runCommand(
      'gsettings',
      ['get', 'org.gnome.desktop.session', 'idle-delay'],
    );
    final lockEnabledFuture = _runCommand(
      'gsettings',
      ['get', 'org.gnome.desktop.screensaver', 'lock-enabled'],
    );
    final ufwFuture = _runCommand('ufw', ['status']);
    final firewallCmdFuture = _runCommand('firewall-cmd', ['--state']);
    final onePasswordFuture = _firstExistingPath([
      '/opt/1Password/1password',
      '/usr/bin/1password',
      '/usr/share/1password/1password',
      '/snap/bin/1password',
    ]);
    final suspiciousArtifactsFuture = _existingPaths([
      '/usr/bin/anydesk',
      '/opt/anydesk/anydesk',
      '/usr/bin/rustdesk',
      '/opt/rustdesk/rustdesk',
      '/usr/bin/teamviewer',
      '/opt/teamviewer/tv_bin/teamviewer',
      '/usr/local/bin/ngrok',
      '/snap/bin/ngrok',
      '/usr/local/bin/cloudflared',
      '/usr/bin/cloudflared',
      '/etc/systemd/system/anydesk.service',
      '/etc/systemd/system/teamviewerd.service',
      '/etc/systemd/system/rustdesk.service',
    ]);
    final endpointProtectionFuture = _existingPaths([
      '/usr/bin/mdatp',
      '/opt/microsoft/mdatp/sbin/wdavdaemon',
      '/opt/CrowdStrike/falcond',
      '/opt/sentinelone/bin/sentinelctl',
      '/opt/sophos-spl/bin/sophos_managementagent',
      '/opt/Malwarebytes/bin/mbdaemon',
      '/usr/bin/osqueryi',
      '/usr/bin/osqueryd',
      '/etc/systemd/system/mdatp.service',
      '/etc/systemd/system/falcon-sensor.service',
      '/etc/systemd/system/sentinelone.service',
      '/etc/systemd/system/osqueryd.service',
      '/var/ossec/bin/wazuh-control',
    ]);

    final encryption = await encryptionFuture;
    final idle = await idleFuture;
    final lockEnabled = await lockEnabledFuture;
    final ufw = await ufwFuture;
    final firewallCmd = await firewallCmdFuture;
    final onePasswordLocation = await onePasswordFuture;
    final suspiciousArtifacts = await suspiciousArtifactsFuture;
    final endpointProtection = await endpointProtectionFuture;

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
      DesktopProbeParsers.parseSuspiciousArtifacts(
        findings: suspiciousArtifacts,
        scanCompleted: true,
      ),
      DesktopProbeParsers.parseEndpointProtection(
        findings: endpointProtection,
        scanCompleted: true,
      ),
    ];
  }

  List<SecurityCheckResult> _unsupportedDesktopChecks() {
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
      SecurityCheckResult(
        id: 'suspicious_artifacts',
        label: 'Suspicious apps and files',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary:
            'This desktop platform is not supported by the automatic probes.',
      ),
      SecurityCheckResult(
        id: 'endpoint_protection',
        label: 'Endpoint malware protection / EDR',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary:
            'This desktop platform is not supported by the automatic probes.',
      ),
    ];
  }

  Future<ProbeCommandResult> _runPowerShell(String script) {
    return _runCommand('powershell', ['-NoProfile', '-Command', script]);
  }

  static Future<ProbeCommandResult> _runProcess(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await Process.run(executable, arguments)
          .timeout(const Duration(seconds: 8));
      return ProbeCommandResult(
        stdout: '${result.stdout}'.trim(),
        stderr: '${result.stderr}'.trim(),
        exitCode: result.exitCode,
      );
    } on TimeoutException {
      return const ProbeCommandResult(
        stdout: '',
        stderr: 'Timed out while running probe.',
        exitCode: -1,
      );
    } on ProcessException catch (error) {
      return ProbeCommandResult(
        stdout: '',
        stderr: error.message,
        exitCode: -1,
      );
    }
  }

  static Future<bool> _fileSystemPathExists(String path) async {
    return await FileSystemEntity.type(path) != FileSystemEntityType.notFound;
  }

  Future<String?> _firstExistingPath(List<String> paths) async {
    for (final path in paths) {
      if (await _pathExists(path)) {
        return path;
      }
    }
    return null;
  }

  Future<List<String>> _existingPaths(List<String> paths) async {
    final findings = <String>[];
    for (final path in paths) {
      if (await _pathExists(path)) {
        findings.add(path);
      }
    }
    return findings;
  }

  static Object? _decodeJson(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  static List<String> _decodeJsonStringList(String value) {
    // ConvertTo-Json emits a bare string for a single finding and an array
    // for multiple findings.
    return switch (_decodeJson(value)) {
      final String single when single.trim().isNotEmpty => [single],
      final List<dynamic> items => items
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      _ => const [],
    };
  }
}
