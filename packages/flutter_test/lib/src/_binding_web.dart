import 'package:flutter/widgets.dart';

import 'binding.dart';

TestWidgetsFlutterBinding ensureInitialized(
    [@visibleForTesting Map<String, String>? environment]) {
  return AutomatedTestWidgetsFlutterBinding.ensureInitialized();
}

void setupHttpOverrides() {}

void mockFlutterAssets() {}
