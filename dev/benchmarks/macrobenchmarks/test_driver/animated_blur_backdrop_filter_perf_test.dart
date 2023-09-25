
import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTest(
    'animated_blur_backdrop_filter_perf',
    kAnimatedBlurBackdropFilter,
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
  );
}