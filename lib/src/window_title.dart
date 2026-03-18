import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowTitle {
  static const _channel = MethodChannel('helixiora/window_title');

  static Future<void> sync(String title) async {
    if (kIsWeb) {
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        break;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return;
    }

    try {
      await _channel.invokeMethod<void>('setWindowTitle', title);
    } on MissingPluginException {
      // Ignore missing native handlers on unsupported hosts.
    } on PlatformException {
      // Keep startup resilient if the platform channel fails.
    }
  }
}
