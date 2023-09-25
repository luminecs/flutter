
@TestOn('!chrome')
library;

import 'package:flutter_test/flutter_test.dart';

import '../../../../examples/layers/rendering/custom_coordinate_systems.dart';
import '../rendering/rendering_tester.dart';

void main() {
  TestRenderingFlutterBinding.ensureInitialized();
  test('Sector layout can paint', () {
    layout(buildSectorExample(), phase: EnginePhase.composite);
  });
}