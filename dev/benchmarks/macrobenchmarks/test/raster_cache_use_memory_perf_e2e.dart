import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTestE2E(
    'raster_cache_use_memory_perf',
    kRasterCacheUseMemory,
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
  );
}
