
import 'package:flutter_driver/flutter_driver.dart';
import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTest(
    'fullscreen_textfield_perf',
    kFullscreenTextRouteName,
    pageDelay: const Duration(seconds: 1),
    driverOps: (FlutterDriver driver) async {
      final SerializableFinder textfield = find.byValueKey('fullscreen-textfield');
      driver.tap(textfield);
      await Future<void>.delayed(const Duration(milliseconds: 5000));
    },
  );
}