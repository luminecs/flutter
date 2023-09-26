// The test should be run as:
// flutter drive -t test/cull_opacity_perf_e2e.dart --driver test_driver/e2e_test.dart --trace-startup --profile

import 'package:macrobenchmarks/common.dart';

import 'util.dart';

Future<void> main() async {
  macroPerfTestE2E(
    'cull_opacity_perf',
    kCullOpacityRouteName,
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
  );
}
