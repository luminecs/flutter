
import 'package:flutter_test/flutter_test.dart';
import 'package:texture/main.dart' as texture;

void main() {
  testWidgets('Texture smoke test', (WidgetTester tester) async {
    texture
        .main(); // builds the app and schedules a frame but doesn't trigger one
    await tester.pump(); // triggers a frame

    expect(find.text('Fluter Blue'), findsOneWidget);
  });
}