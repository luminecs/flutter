import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTestE2E(
    'multi_widget_construction_perf',
    kMultiWidgetConstructionRouteName,
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
  );
}
