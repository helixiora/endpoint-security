import '../models.dart';
import 'native_inspection.dart';

/// Fallback used when dart:io is unavailable (the web). The inspector guards
/// all web behavior behind kIsWeb before touching this adapter, so these
/// values are only ever read on platforms nobody ships to.
NativeInspection createNativeInspection() => _UnsupportedNativeInspection();

class _UnsupportedNativeInspection implements NativeInspection {
  @override
  NativePlatform get platform => NativePlatform.other;

  @override
  String get localHostname => 'Unknown';

  @override
  String get operatingSystem => 'unsupported';

  @override
  String get operatingSystemVersion => 'Unknown';

  @override
  Future<String> runCommand(String executable, List<String> arguments) async {
    return '';
  }

  @override
  Future<List<SecurityCheckResult>> runDesktopProbes() async => const [];
}
