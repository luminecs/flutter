import 'package:flutter/material.dart';

import 'material3.dart';
import 'recorder.dart';

class BenchMaterial3Components extends WidgetBuildRecorder {
  BenchMaterial3Components() : super(name: benchmarkName);

  static const String benchmarkName = 'bench_material3_components';

  @override
  Widget createWidget() {
    return const TwoColumnMaterial3Components();
  }
}
