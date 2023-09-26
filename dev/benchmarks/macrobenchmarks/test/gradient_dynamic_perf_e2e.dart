import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTestMultiPageE2E(
    'gradient_dynamic_perf',
    <ScrollableButtonRoute>[
      ScrollableButtonRoute(kScrollableName, kGradientPerfRouteName),
      ScrollableButtonRoute(
          kGradientPerfScrollableName, kGradientPerfRecreateDynamicRouteName),
    ],
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
  );
}
