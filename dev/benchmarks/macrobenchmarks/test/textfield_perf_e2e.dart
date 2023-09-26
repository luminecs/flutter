import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTestE2E(
    'textfield_perf',
    kTextRouteName,
    pageDelay: const Duration(seconds: 1),
    body: (WidgetController controller) async {
      final Finder textfield =
          find.byKey(const ValueKey<String>('basic-textfield'));
      controller.tap(textfield);
      // Caret should be cached, so repeated blinking should not require recompute.
      await Future<void>.delayed(const Duration(milliseconds: 5000));
    },
  );
}
