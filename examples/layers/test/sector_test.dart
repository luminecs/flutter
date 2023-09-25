
import 'package:flutter_test/flutter_test.dart';

import '../rendering/src/sector_layout.dart';
import '../widgets/sectors.dart';

void main() {
  test('SectorConstraints', () {
    expect(const SectorConstraints().isTight, isFalse);
  });

  testWidgets('Sector Sixes', (WidgetTester tester) async {
    await tester.pumpWidget(const SectorApp());
  });
}