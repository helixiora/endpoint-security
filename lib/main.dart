import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/app_config.dart';
import 'src/window_title.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowTitle.sync(AppConfig.windowTitle);
  runApp(const EndpointSecurityApp());
}
