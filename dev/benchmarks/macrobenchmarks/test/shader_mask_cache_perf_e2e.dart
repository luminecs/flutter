import 'package:macrobenchmarks/common.dart';

import 'util.dart';

void main() {
  macroPerfTestE2E(
    'shader_mask_cache_perf',
    kShaderMaskCacheRouteName,
    pageDelay: const Duration(seconds: 1),
    duration: const Duration(seconds: 10),
  );
}
