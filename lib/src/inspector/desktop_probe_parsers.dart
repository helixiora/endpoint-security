import 'dart:convert';

import '../models.dart';

class DesktopProbeParsers {
  static SecurityCheckResult parseMacEncryption({
    required String stdout,
    required String stderr,
    required int exitCode,
  }) {
    final combined = '${stdout.trim()}\n${stderr.trim()}'.toLowerCase();
    if (exitCode == 0 && combined.contains('filevault is on')) {
      return const SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary: 'FileVault is enabled.',
      );
    }
    if (combined.contains('filevault is off')) {
      return const SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.disabled,
        detectedAutomatically: true,
        summary: 'FileVault is disabled.',
      );
    }
    return SecurityCheckResult(
      id: 'disk_encryption',
      label: 'Hard disk encryption',
      detectedStatus: CheckStatus.unknown,
      detectedAutomatically: false,
      summary: 'Could not determine FileVault status automatically.',
      details: _detailsForFailure(stdout, stderr, exitCode),
    );
  }

  static SecurityCheckResult parseMacScreenLock({
    required String idleStdout,
    required String screenLockStatusStdout,
    required String askForPasswordStdout,
    required String askForPasswordDelayStdout,
    required int idleExitCode,
    required int screenLockStatusExitCode,
    required int askForPasswordExitCode,
    required int askForPasswordDelayExitCode,
  }) {
    final idleSeconds = _firstInt(idleStdout);
    final screenLockStatus = screenLockStatusStdout.trim().toLowerCase();
    final askForPassword = _firstInt(askForPasswordStdout);
    final askForPasswordDelay = _firstInt(askForPasswordDelayStdout) ?? 0;

    if (idleExitCode != 0 || idleSeconds == null) {
      return const SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Could not read macOS screensaver settings automatically.',
        details:
            'Open System Settings and confirm that the Mac locks automatically when it becomes idle.',
      );
    }

    if (idleSeconds <= 0) {
      return const SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.disabled,
        detectedAutomatically: true,
        summary: 'The screensaver idle timer is disabled.',
      );
    }

    if (screenLockStatusExitCode == 0 &&
        screenLockStatus.contains('delay is')) {
      if (screenLockStatus.contains('off')) {
        return SecurityCheckResult(
          id: 'screen_lock',
          label: 'Screensaver / screen lock',
          detectedStatus: CheckStatus.disabled,
          detectedAutomatically: true,
          summary:
              'The screensaver starts after $idleSeconds seconds but screen lock is turned off.',
        );
      }

      final delayMatch = RegExp(r'delay is (immediate|(\d+))').firstMatch(
        screenLockStatus,
      );
      final delayLabel = delayMatch?.group(1) ?? 'configured';
      return SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary:
            'The screensaver starts after $idleSeconds seconds and locks with a $delayLabel delay.',
      );
    }

    if (askForPasswordExitCode != 0 || askForPassword == null) {
      return SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary:
            'This Mac starts the screensaver after $idleSeconds seconds, but the app could not confirm whether a password is required to unlock it.',
        details:
            'If the Mac requires a password when the screensaver starts or the display sleeps, choose Enabled below.',
      );
    }

    if (askForPassword == 1) {
      return SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary:
            'The screensaver starts after $idleSeconds seconds and requires a password.',
        details: 'Password delay: $askForPasswordDelay seconds.',
      );
    }

    return SecurityCheckResult(
      id: 'screen_lock',
      label: 'Screensaver / screen lock',
      detectedStatus: CheckStatus.disabled,
      detectedAutomatically: true,
      summary:
          'The screensaver starts after $idleSeconds seconds but does not require a password.',
      details: 'Password delay: $askForPasswordDelay seconds.',
    );
  }

  static SecurityCheckResult parseMacFirewall({
    required String stdout,
    required String stderr,
    required int exitCode,
  }) {
    final combined = '${stdout.trim()}\n${stderr.trim()}'.toLowerCase();
    if (combined.contains('enabled')) {
      return const SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary: 'The macOS application firewall is enabled.',
      );
    }
    if (combined.contains('disabled')) {
      return const SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.disabled,
        detectedAutomatically: true,
        summary: 'The macOS application firewall is disabled.',
      );
    }
    return SecurityCheckResult(
      id: 'firewall',
      label: 'Firewall',
      detectedStatus: CheckStatus.unknown,
      detectedAutomatically: false,
      summary: 'Could not determine firewall state automatically.',
      details: _detailsForFailure(stdout, stderr, exitCode),
    );
  }

  static SecurityCheckResult parseWindowsBitLocker({
    required String stdout,
    required String stderr,
    required int exitCode,
  }) {
    final payload = _decodeJson(stdout);
    if (payload is! Map<String, dynamic>) {
      return SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Could not read BitLocker status automatically.',
        details: _detailsForFailure(stdout, stderr, exitCode),
      );
    }

    final protectionStatus = '${payload['ProtectionStatus']}'.toLowerCase();
    final encryptionMethod = '${payload['EncryptionMethod'] ?? ''}'.trim();

    if (protectionStatus == '1' || protectionStatus.contains('on')) {
      return SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary: 'BitLocker is enabled for the system drive.',
        details: encryptionMethod.isEmpty
            ? null
            : 'Encryption method: $encryptionMethod.',
      );
    }

    if (protectionStatus == '0' || protectionStatus.contains('off')) {
      return SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.disabled,
        detectedAutomatically: true,
        summary: 'BitLocker is disabled for the system drive.',
        details: encryptionMethod.isEmpty
            ? null
            : 'Encryption method: $encryptionMethod.',
      );
    }

    return SecurityCheckResult(
      id: 'disk_encryption',
      label: 'Hard disk encryption',
      detectedStatus: CheckStatus.unknown,
      detectedAutomatically: false,
      summary: 'BitLocker returned an unexpected protection state.',
      details: _detailsForFailure(stdout, stderr, exitCode),
    );
  }

  static SecurityCheckResult parseWindowsScreenLock({
    required String stdout,
    required String stderr,
    required int exitCode,
  }) {
    final payload = _decodeJson(stdout);
    if (payload is! Map<String, dynamic>) {
      return SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Could not read Windows screen saver settings automatically.',
        details: _detailsForFailure(stdout, stderr, exitCode),
      );
    }

    final active = '${payload['Active'] ?? ''}'.trim();
    final secure = '${payload['Secure'] ?? ''}'.trim();
    final timeout = int.tryParse('${payload['Timeout'] ?? ''}'.trim()) ?? 0;

    if (active.isEmpty || secure.isEmpty) {
      return SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Windows screen saver settings were incomplete.',
        details: _detailsForFailure(stdout, stderr, exitCode),
      );
    }

    if (active == '1' && secure == '1' && timeout > 0) {
      return SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary:
            'The screen saver is enabled, secure, and starts after $timeout seconds.',
      );
    }

    if (active == '0' || timeout <= 0) {
      return const SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.disabled,
        detectedAutomatically: true,
        summary: 'The Windows screen saver timeout is disabled.',
      );
    }

    return SecurityCheckResult(
      id: 'screen_lock',
      label: 'Screensaver / screen lock',
      detectedStatus: CheckStatus.disabled,
      detectedAutomatically: true,
      summary:
          'The screen saver is active but unlock does not require credentials.',
      details: 'Active=$active Secure=$secure Timeout=$timeout',
    );
  }

  static SecurityCheckResult parseWindowsFirewall({
    required String stdout,
    required String stderr,
    required int exitCode,
  }) {
    final payload = _decodeJson(stdout);
    final profiles = switch (payload) {
      List<dynamic> value => value.whereType<Map>().map((e) {
          return Map<String, dynamic>.from(
            e.map((key, value) => MapEntry('$key', value)),
          );
        }).toList(),
      Map<String, dynamic> value => [value],
      _ => <Map<String, dynamic>>[],
    };

    if (profiles.isEmpty) {
      return SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Could not read Windows firewall profiles automatically.',
        details: _detailsForFailure(stdout, stderr, exitCode),
      );
    }

    final enabledCount = profiles.where((profile) {
      return profile['Enabled'] == true ||
          '${profile['Enabled']}'.toLowerCase() == 'true';
    }).length;

    if (enabledCount == profiles.length) {
      return const SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary: 'All Windows firewall profiles are enabled.',
      );
    }

    if (enabledCount == 0) {
      return const SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.disabled,
        detectedAutomatically: true,
        summary: 'No Windows firewall profiles are enabled.',
      );
    }

    return SecurityCheckResult(
      id: 'firewall',
      label: 'Firewall',
      detectedStatus: CheckStatus.manualReview,
      detectedAutomatically: true,
      summary: 'Only some Windows firewall profiles are enabled.',
      details:
          'Profiles: ${profiles.map((profile) => '${profile['Name']}:${profile['Enabled']}').join(', ')}',
    );
  }

  static SecurityCheckResult parseLinuxEncryption({
    required String stdout,
    required String stderr,
    required int exitCode,
  }) {
    final source = stdout.trim().toLowerCase();
    if (exitCode == 0 &&
        (source.contains('/dev/mapper/') ||
            source.contains('crypt') ||
            source.contains('luks'))) {
      return SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary:
            'The Linux root volume appears to sit on an encrypted mapper device.',
        details: 'Root volume source: ${stdout.trim()}',
      );
    }

    if (source.startsWith('/dev/')) {
      return SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Linux disk encryption could not be confirmed automatically.',
        details: 'Root volume source: ${stdout.trim()}',
      );
    }

    return SecurityCheckResult(
      id: 'disk_encryption',
      label: 'Hard disk encryption',
      detectedStatus: CheckStatus.unknown,
      detectedAutomatically: false,
      summary:
          'Could not determine the Linux root volume source automatically.',
      details: _detailsForFailure(stdout, stderr, exitCode),
    );
  }

  static SecurityCheckResult parseLinuxScreenLock({
    required String idleStdout,
    required String lockEnabledStdout,
    required int idleExitCode,
    required int lockEnabledExitCode,
  }) {
    final idleSeconds = _firstInt(idleStdout);
    final lockEnabled = lockEnabledStdout.trim().toLowerCase();

    if (idleExitCode != 0 ||
        lockEnabledExitCode != 0 ||
        idleSeconds == null ||
        (lockEnabled != 'true' && lockEnabled != 'false')) {
      return SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary:
            'Could not read Linux desktop screen lock settings automatically.',
        details: 'idle=$idleStdout lockEnabled=$lockEnabledStdout',
      );
    }

    if (idleSeconds > 0 && lockEnabled == 'true') {
      return SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary: 'The desktop locks after $idleSeconds seconds of inactivity.',
      );
    }

    if (idleSeconds <= 0) {
      return const SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.disabled,
        detectedAutomatically: true,
        summary: 'The Linux idle timeout is disabled.',
      );
    }

    return SecurityCheckResult(
      id: 'screen_lock',
      label: 'Screensaver / screen lock',
      detectedStatus: CheckStatus.disabled,
      detectedAutomatically: true,
      summary:
          'The session goes idle after $idleSeconds seconds but the lock screen is disabled.',
    );
  }

  static SecurityCheckResult parseLinuxFirewall({
    required String ufwStdout,
    required int ufwExitCode,
    required String firewallCmdStdout,
    required int firewallCmdExitCode,
  }) {
    final ufw = ufwStdout.toLowerCase();
    final firewallCmd = firewallCmdStdout.toLowerCase();

    if (ufwExitCode == 0 && ufw.contains('status: active')) {
      return const SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary: 'UFW is active.',
      );
    }

    if (ufwExitCode == 0 && ufw.contains('status: inactive')) {
      return const SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.disabled,
        detectedAutomatically: true,
        summary: 'UFW is installed but inactive.',
      );
    }

    if (firewallCmdExitCode == 0 && firewallCmd.contains('running')) {
      return const SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary: 'firewalld is running.',
      );
    }

    return SecurityCheckResult(
      id: 'firewall',
      label: 'Firewall',
      detectedStatus: CheckStatus.manualReview,
      detectedAutomatically: false,
      summary: 'Could not confirm Linux firewall status automatically.',
      details: 'ufw=$ufwStdout firewalld=$firewallCmdStdout',
    );
  }

  static SecurityCheckResult parseInstalledApp({
    required String label,
    required String id,
    required bool installed,
    required String? location,
  }) {
    return SecurityCheckResult(
      id: id,
      label: label,
      detectedStatus: installed ? CheckStatus.enabled : CheckStatus.disabled,
      detectedAutomatically: true,
      summary: installed
          ? '$label was found on this device.'
          : '$label was not found in the expected install locations.',
      details:
          location == null || location.isEmpty ? null : 'Detected at $location',
    );
  }

  static SecurityCheckResult parseSuspiciousArtifacts({
    required List<String> findings,
    required bool scanCompleted,
    String? failureDetails,
  }) {
    if (!scanCompleted) {
      return SecurityCheckResult(
        id: 'suspicious_artifacts',
        label: 'Suspicious apps and files',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary:
            'The app could not complete the suspicious app and file scan automatically.',
        details: failureDetails,
      );
    }

    if (findings.isEmpty) {
      return const SecurityCheckResult(
        id: 'suspicious_artifacts',
        label: 'Suspicious apps and files',
        detectedStatus: CheckStatus.enabled,
        detectedAutomatically: true,
        summary:
            'No suspicious apps or files were found in the checked locations.',
        details:
            'This is a limited indicator scan, not a full antivirus or EDR scan.',
      );
    }

    return SecurityCheckResult(
      id: 'suspicious_artifacts',
      label: 'Suspicious apps and files',
      detectedStatus: CheckStatus.disabled,
      detectedAutomatically: true,
      summary:
          'Potentially suspicious apps or files were found and should be reviewed.',
      details: [
        'Findings:',
        ...findings.map((finding) => '- $finding'),
        '',
        'This is a limited indicator scan, not a full antivirus or EDR scan.',
      ].join('\n'),
    );
  }

  static int? _firstInt(String value) {
    final match = RegExp(r'(-?\d+)').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(1)!);
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

  static String _detailsForFailure(String stdout, String stderr, int exitCode) {
    final parts = <String>[
      'exitCode=$exitCode',
      if (stdout.trim().isNotEmpty) 'stdout=${stdout.trim()}',
      if (stderr.trim().isNotEmpty) 'stderr=${stderr.trim()}',
    ];
    return parts.join(' | ');
  }
}
