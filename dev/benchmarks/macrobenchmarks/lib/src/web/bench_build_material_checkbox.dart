
import 'package:flutter/material.dart';

import 'recorder.dart';

class BenchBuildMaterialCheckbox extends WidgetBuildRecorder {
  BenchBuildMaterialCheckbox() : super(name: benchmarkName);

  static const String benchmarkName = 'build_material_checkbox';

  static bool? _isChecked;

  @override
  Widget createWidget() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        child: Column(
          children: List<Widget>.generate(10, (int i) {
            return _buildRow();
          }),
        ),
      ),
    );
  }

  Row _buildRow() {
    if (_isChecked == null) {
      _isChecked = true;
    } else if (_isChecked!) {
      _isChecked = false;
    } else {
      _isChecked = null;
    }

    return Row(
      children: List<Widget>.generate(10, (int i) {
        return Expanded(
          child: Checkbox(
            value: _isChecked,
            tristate: true,
            onChanged: (bool? newValue) {
              // Intentionally empty.
            },
          ),
        );
      }),
    );
  }
}