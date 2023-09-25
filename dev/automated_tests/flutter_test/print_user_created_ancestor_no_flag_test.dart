
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Rendering Error', (WidgetTester tester) async {
    // this should fail
    await tester.pumpWidget(
      CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: Container()),
        ],
      )
    );
  });
}