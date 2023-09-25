import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTest(
    'animated_advanced_blend_perf',
    kAnimatedAdvancedBlend,
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
  );
}