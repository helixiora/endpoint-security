import 'dart:io';

import '../models.dart';
import 'desktop_probes.dart';
import 'native_inspection.dart';

NativeInspection createNativeInspection() => _IoNativeInspection();

class _IoNativeInspection implements NativeInspection {
  final DesktopProbes _probes = DesktopProbes();

  @override
  NativePlatform get platform {
    if (Platform.isMacOS) {
      return NativePlatform.macOS;
    }
    if (Platform.isWindows) {
      return NativePlatform.windows;
    }
    if (Platform.isLinux) {
      return NativePlatform.linux;
    }
    if (Platform.isAndroid) {
      return NativePlatform.android;
    }
    if (Platform.isIOS) {
      return NativePlatform.ios;
    }
    return NativePlatform.other;
  }

  @override
  String get localHostname => Platform.localHostname;

  @override
  String get operatingSystem => Platform.operatingSystem;

  @override
  String get operatingSystemVersion => Platform.operatingSystemVersion;

  @override
  Future<String> runCommand(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(executable, arguments)
          .timeout(const Duration(seconds: 8));
      final combined = [
        result.stdout.toString(),
        result.stderr.toString(),
      ].where((value) => value.trim().isNotEmpty).join('\n');
      return combined.trim();
    } catch (_) {
      return '';
    }
  }

  @override
  Future<List<SecurityCheckResult>> runDesktopProbes() => _probes.run();
}
