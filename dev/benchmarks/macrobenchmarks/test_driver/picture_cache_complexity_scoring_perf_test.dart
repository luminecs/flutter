import 'package:flutter_driver/flutter_driver.dart';
import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTest(
    'picture_cache_complexity_scoring_perf',
    kPictureCacheComplexityScoringRouteName,
    pageDelay: const Duration(seconds: 1),
    driverOps: (FlutterDriver driver) async {
      final SerializableFinder tabBarView = find.byValueKey('tabbar_view_complexity');
      Future<void> scrollOnce(double offset) async {
        // Technically it's not scrolling but moving
        await driver.scroll(tabBarView, offset, 0.0, const Duration(milliseconds: 300));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      // When we eventually add more test panes we will want to tweak these
      // to go through all the panes
      for (int i = 0; i < 6; i += 1) {
        await scrollOnce(-300.0);
        await scrollOnce(300.0);
      }
    },
  );
}