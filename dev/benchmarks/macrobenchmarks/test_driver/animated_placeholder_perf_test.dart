import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTest(
    'animated_placeholder_perf',
    kAnimatedPlaceholderRouteName,
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 5),
  );
}