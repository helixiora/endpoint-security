import '../models.dart';

enum NativePlatform { macOS, windows, linux, android, ios, other }

/// The dart:io-dependent surface the inspector needs, kept behind a
/// conditional import so web builds never compile dart:io code.
abstract class NativeInspection {
  NativePlatform get platform;

  String get localHostname;

  String get operatingSystem;

  String get operatingSystemVersion;

  /// Runs a local command and returns its combined trimmed output, or an
  /// empty string when the command fails or times out.
  Future<String> runCommand(String executable, List<String> arguments);

  Future<List<SecurityCheckResult>> runDesktopProbes();
}
