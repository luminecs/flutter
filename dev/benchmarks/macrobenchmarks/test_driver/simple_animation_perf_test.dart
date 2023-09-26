import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTest(
    'simple_animation_perf',
    kSimpleAnimationRouteName,
    pageDelay: const Duration(seconds: 10),
    duration: const Duration(seconds: 10),
  );
}
