// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  testWidgetsWithLeakTracking('TrackingScrollController saves offset', (WidgetTester tester) async {
    final TrackingScrollController controller = TrackingScrollController();
    addTearDown(controller.dispose);
    const double listItemHeight = 100.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PageView.builder(
          itemBuilder: (BuildContext context, int index) {
            return ListView(
              controller: controller,
              children: List<Widget>.generate(
                10,
                (int i) => SizedBox(
                  height: listItemHeight,
                  child: Text('Page$index-Item$i'),
                ),
              ).toList(),
            );
          },
        ),
      ),
    );

    expect(find.text('Page0-Item1'), findsOneWidget);
    expect(find.text('Page1-Item1'), findsNothing);
    expect(find.text('Page2-Item0'), findsNothing);
    expect(find.text('Page2-Item1'), findsNothing);

    controller.jumpTo(listItemHeight + 10);
    await tester.pumpAndSettle();

    await tester.fling(find.text('Page0-Item1'), const Offset(-100.0, 0.0), 10000.0);
    await tester.pumpAndSettle();

    expect(find.text('Page0-Item1'), findsNothing);
    expect(find.text('Page1-Item1'), findsOneWidget);
    expect(find.text('Page2-Item0'), findsNothing);
    expect(find.text('Page2-Item1'), findsNothing);

    await tester.fling(find.text('Page1-Item1'), const Offset(-100.0, 0.0), 10000.0);
    await tester.pumpAndSettle();

    expect(find.text('Page0-Item1'), findsNothing);
    expect(find.text('Page1-Item1'), findsNothing);
    expect(find.text('Page2-Item0'), findsNothing);
    expect(find.text('Page2-Item1'), findsOneWidget);

    await tester.pumpWidget(const Text('Another page', textDirection: TextDirection.ltr));

    expect(controller.initialScrollOffset, 0.0);
  });
}