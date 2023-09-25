import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTestMultiPageE2E(
    'opacity_peephole_col_of_rows_perf',
    <ScrollableButtonRoute>[
      ScrollableButtonRoute(kScrollableName, kOpacityPeepholeRouteName),
      ScrollableButtonRoute(kOpacityScrollableName, kOpacityPeepholeOpacityOfColOfRowsRouteName),
    ],
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
  );
}