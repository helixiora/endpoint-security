import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import 'desktop_probes.dart';

class EndpointInspector {
  EndpointInspector({DeviceInfoPlugin? deviceInfo})
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;
  static const _deviceIdentifierChannel = MethodChannel(
    'helixiora.endpoint_security/device_identifiers',
  );

  Future<EndpointInspectionReport> inspect() async {
    final device = await _readDeviceContext();
    final checks = await _readChecks(device.platform);

    return EndpointInspectionReport(
      collectedAt: DateTime.now().toUtc(),
      device: device,
      checks: checks,
    );
  }

  Future<DeviceContext> _readDeviceContext() async {
    if (Platform.isMacOS) {
      final info = await _deviceInfo.macOsInfo;
      final identifier = await _readMacDeviceIdentifier();
      return DeviceContext(
        platform: 'macOS',
        osVersion:
            '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
        deviceModel: info.model,
        endpointName: Platform.localHostname,
        deviceIdentifierLabel: identifier.$1,
        deviceIdentifier: identifier.$2,
      );
    }

    if (Platform.isWindows) {
      final info = await _deviceInfo.windowsInfo;
      return DeviceContext(
        platform: 'Windows',
        osVersion: info.displayVersion,
        deviceModel: info.computerName,
        endpointName: info.computerName,
        deviceIdentifierLabel: 'Device ID',
        deviceIdentifier: _preferredIdentifier(
              info.deviceId,
              fallback: info.computerName,
            ) ??
            'Unavailable',
      );
    }

    if (Platform.isLinux) {
      final info = await _deviceInfo.linuxInfo;
      return DeviceContext(
        platform: 'Linux',
        osVersion: info.version ?? 'Unknown',
        deviceModel: info.prettyName,
        endpointName: Platform.localHostname,
        deviceIdentifierLabel: 'Machine ID',
        deviceIdentifier: _preferredIdentifier(
              info.machineId,
              fallback: Platform.localHostname,
            ) ??
            'Unavailable',
      );
    }

    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      final androidId = await _readAndroidId();
      final serialNumber = _preferredIdentifier(
        info.data['serialNumber']?.toString(),
      );
      final identifier = _preferredIdentifier(
        androidId,
        fallback: _preferredIdentifier(
          serialNumber,
          fallback: _preferredIdentifier(
            info.id,
            fallback: _preferredIdentifier(info.fingerprint),
          ),
        ),
      );
      return DeviceContext(
        platform: 'Android',
        osVersion: 'Android ${info.version.release}',
        deviceModel: '${info.brand} ${info.model}',
        endpointName: info.model,
        deviceIdentifierLabel: androidId != null
            ? 'Android ID'
            : serialNumber != null
                ? 'Serial number'
                : 'Build ID',
        deviceIdentifier: identifier ?? 'Unavailable',
      );
    }

    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return DeviceContext(
        platform: 'iOS',
        osVersion: '${info.systemName} ${info.systemVersion}',
        deviceModel: '${info.model} (${info.utsname.machine})',
        endpointName: info.name,
        deviceIdentifierLabel: 'Identifier for vendor',
        deviceIdentifier: _preferredIdentifier(
              info.identifierForVendor,
            ) ??
            'Unavailable',
      );
    }

    return DeviceContext(
      platform: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      deviceModel: 'Unknown device',
      endpointName: Platform.localHostname,
      deviceIdentifierLabel: 'Device identifier',
      deviceIdentifier: Platform.localHostname,
    );
  }

  Future<List<SecurityCheckResult>> _readChecks(String platform) async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return DesktopProbes.run();
    }

    return _manualChecksForMobile(platform);
  }

  List<SecurityCheckResult> _manualChecksForMobile(String platform) {
    return [
      SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Review required on $platform.',
        details:
            'Mobile operating systems do not expose a portable API for third-party apps to verify storage encryption.',
      ),
      SecurityCheckResult(
        id: 'screen_lock',
        label: 'Screensaver / screen lock',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Review required on $platform.',
        details:
            'This app cannot reliably inspect auto-lock and password rules on $platform without enterprise device management permissions.',
      ),
      const SecurityCheckResult(
        id: 'firewall',
        label: 'Firewall',
        detectedStatus: CheckStatus.notApplicable,
        detectedAutomatically: false,
        summary: 'Not applicable on typical mobile devices.',
        details:
            'There is no general end-user firewall setting that a regular mobile app can inspect across all devices.',
      ),
      SecurityCheckResult(
        id: 'one_password',
        label: '1Password installed',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Review required on $platform.',
        details:
            'Installed app visibility is restricted on mobile platforms, especially on iOS.',
      ),
      SecurityCheckResult(
        id: 'suspicious_artifacts',
        label: 'Suspicious apps and files',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Review required on $platform.',
        details:
            'Mobile operating systems do not expose a portable API for regular apps to inspect installed apps and files broadly.',
      ),
      SecurityCheckResult(
        id: 'endpoint_protection',
        label: 'Endpoint malware protection / EDR',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Review required on $platform.',
        details:
            'Confirm whether this mobile device is managed by MDM or protected by an approved mobile threat defense solution.',
      ),
    ];
  }

  Future<(String, String)> _readMacDeviceIdentifier() async {
    final details = await _runCommand(
      '/usr/sbin/ioreg',
      ['-rd1', '-c', 'IOPlatformExpertDevice'],
    );
    final serialNumber = _firstMatch(
      details,
      RegExp(r'"IOPlatformSerialNumber"\s*=\s*"([^"]+)"'),
    );
    if (serialNumber != null) {
      return ('Serial number', serialNumber);
    }

    final hardwareUuid = _firstMatch(
      details,
      RegExp(r'"IOPlatformUUID"\s*=\s*"([^"]+)"'),
    );
    if (hardwareUuid != null) {
      return ('Hardware UUID', hardwareUuid);
    }

    return ('Serial number', Platform.localHostname);
  }

  Future<String?> _readAndroidId() async {
    try {
      final androidId = await _deviceIdentifierChannel.invokeMethod<String>(
        'getAndroidId',
      );
      return _preferredIdentifier(androidId);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<String> _runCommand(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(executable, arguments);
      final combined = [
        result.stdout.toString(),
        result.stderr.toString(),
      ].where((value) => value.trim().isNotEmpty).join('\n');
      return combined.trim();
    } catch (_) {
      return '';
    }
  }

  String? _firstMatch(String input, RegExp pattern) {
    final match = pattern.firstMatch(input);
    return _preferredIdentifier(match?.group(1));
  }

  String? _preferredIdentifier(String? value, {String? fallback}) {
    final normalized = _normalizeIdentifier(value);
    if (normalized != null) {
      return normalized;
    }
    return _normalizeIdentifier(fallback);
  }

  String? _normalizeIdentifier(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    const blockedValues = {
      'unknown',
      'unknown serial',
      'n/a',
      'na',
      'null',
      'unavailable',
    };
    if (blockedValues.contains(trimmed.toLowerCase())) {
      return null;
    }

    return trimmed;
  }
}
