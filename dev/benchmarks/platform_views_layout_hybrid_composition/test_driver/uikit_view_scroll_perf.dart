import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';

import 'package:platform_views_layout_hybrid_composition/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  runApp(const app.PlatformViewApp());
}
