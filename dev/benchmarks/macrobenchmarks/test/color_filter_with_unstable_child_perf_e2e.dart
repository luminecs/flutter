import 'package:macrobenchmarks/common.dart';

import 'util.dart';

Future<void> main() async {
  macroPerfTestE2E(
    'color_filter_with_unstable_child_perf',
    kColorFilterWithUnstableChildName,
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
  );
}