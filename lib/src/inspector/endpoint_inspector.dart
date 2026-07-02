import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import 'native_inspection.dart';
import 'native_inspection_unsupported.dart'
    if (dart.library.io) 'native_inspection_io.dart' as native;

class EndpointInspector {
  EndpointInspector({
    DeviceInfoPlugin? deviceInfo,
    NativeInspection? nativeInspection,
  })  : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _native = nativeInspection ?? native.createNativeInspection();

  final DeviceInfoPlugin _deviceInfo;
  final NativeInspection _native;
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
    // The web has no dart:io, so the web branch must come before any use of
    // the native adapter.
    if (kIsWeb) {
      final info = await _deviceInfo.webBrowserInfo;
      final browser = info.browserName.name;
      return DeviceContext(
        platform: 'Web',
        osVersion: info.platform ?? 'Unknown',
        deviceModel: 'Browser: $browser',
        endpointName: browser,
        deviceIdentifierLabel: 'Browser',
        deviceIdentifier: _preferredIdentifier(info.userAgent) ?? 'Unavailable',
      );
    }

    switch (_native.platform) {
      case NativePlatform.macOS:
        final info = await _deviceInfo.macOsInfo;
        final identifier = await _readMacDeviceIdentifier();
        return DeviceContext(
          platform: 'macOS',
          osVersion:
              '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
          deviceModel: info.model,
          endpointName: _native.localHostname,
          deviceIdentifierLabel: identifier.$1,
          deviceIdentifier: identifier.$2,
        );

      case NativePlatform.windows:
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

      case NativePlatform.linux:
        final info = await _deviceInfo.linuxInfo;
        return DeviceContext(
          platform: 'Linux',
          osVersion: info.version ?? 'Unknown',
          deviceModel: info.prettyName,
          endpointName: _native.localHostname,
          deviceIdentifierLabel: 'Machine ID',
          deviceIdentifier: _preferredIdentifier(
                info.machineId,
                fallback: _native.localHostname,
              ) ??
              'Unavailable',
        );

      case NativePlatform.android:
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

      case NativePlatform.ios:
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

      case NativePlatform.other:
        return DeviceContext(
          platform: _native.operatingSystem,
          osVersion: _native.operatingSystemVersion,
          deviceModel: 'Unknown device',
          endpointName: _native.localHostname,
          deviceIdentifierLabel: 'Device identifier',
          deviceIdentifier: _native.localHostname,
        );
    }
  }

  Future<List<SecurityCheckResult>> _readChecks(String platform) async {
    if (kIsWeb) {
      return _manualChecks(
        platform,
        firewall: SecurityCheckResult(
          id: 'firewall',
          label: 'Firewall',
          detectedStatus: CheckStatus.manualReview,
          detectedAutomatically: false,
          summary: 'Review required on $platform.',
          details:
              'A browser app cannot inspect the firewall of the machine it runs on. Confirm the host firewall status manually.',
        ),
      );
    }

    switch (_native.platform) {
      case NativePlatform.macOS:
      case NativePlatform.windows:
      case NativePlatform.linux:
        return _native.runDesktopProbes();
      case NativePlatform.android:
      case NativePlatform.ios:
      case NativePlatform.other:
        return _manualChecks(
          platform,
          firewall: const SecurityCheckResult(
            id: 'firewall',
            label: 'Firewall',
            detectedStatus: CheckStatus.notApplicable,
            detectedAutomatically: false,
            summary: 'Not applicable on typical mobile devices.',
            details:
                'There is no general end-user firewall setting that a regular mobile app can inspect across all devices.',
          ),
        );
    }
  }

  List<SecurityCheckResult> _manualChecks(
    String platform, {
    required SecurityCheckResult firewall,
  }) {
    return [
      SecurityCheckResult(
        id: 'disk_encryption',
        label: 'Hard disk encryption',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Review required on $platform.',
        details:
            'This platform does not expose a portable API for third-party apps to verify storage encryption.',
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
      firewall,
      SecurityCheckResult(
        id: 'one_password',
        label: '1Password installed',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Review required on $platform.',
        details:
            'Installed app visibility is restricted on this platform, so confirm 1Password manually.',
      ),
      SecurityCheckResult(
        id: 'suspicious_artifacts',
        label: 'Suspicious apps and files',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Review required on $platform.',
        details:
            'This platform does not expose a portable API for regular apps to inspect installed apps and files broadly.',
      ),
      SecurityCheckResult(
        id: 'endpoint_protection',
        label: 'Endpoint malware protection / EDR',
        detectedStatus: CheckStatus.manualReview,
        detectedAutomatically: false,
        summary: 'Review required on $platform.',
        details:
            'Confirm whether this device is managed by MDM or protected by an approved endpoint security solution.',
      ),
    ];
  }

  Future<(String, String)> _readMacDeviceIdentifier() async {
    final details = await _native.runCommand(
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

    return ('Serial number', _native.localHostname);
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
