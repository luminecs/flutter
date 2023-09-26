import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import 'semantics_tester.dart';

void main() {
  testWidgetsWithLeakTracking('Semantics 7 - Merging',
      (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    String label;

    label = '1';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MergeSemantics(
              child: Semantics(
                checked: true,
                container: true,
                child: Semantics(
                  container: true,
                  label: label,
                ),
              ),
            ),
            MergeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Semantics(
                    checked: true,
                  ),
                  Semantics(
                    label: label,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    expect(
        semantics,
        hasSemantics(
          TestSemantics.root(
            children: <TestSemantics>[
              TestSemantics.rootChild(
                id: 1,
                flags: SemanticsFlag.hasCheckedState.index |
                    SemanticsFlag.isChecked.index,
                label: label,
                rect: TestSemantics.fullScreen,
              ),
              // IDs 2 and 3 are used up by the nodes that get merged in
              TestSemantics.rootChild(
                id: 4,
                flags: SemanticsFlag.hasCheckedState.index |
                    SemanticsFlag.isChecked.index,
                label: label,
                rect: TestSemantics.fullScreen,
              ),
              // IDs 5 and 6 are used up by the nodes that get merged in
            ],
          ),
        ));

    label = '2';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MergeSemantics(
              child: Semantics(
                checked: true,
                container: true,
                child: Semantics(
                  container: true,
                  label: label,
                ),
              ),
            ),
            MergeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Semantics(
                    checked: true,
                  ),
                  Semantics(
                    label: label,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    expect(
        semantics,
        hasSemantics(
          TestSemantics.root(
            children: <TestSemantics>[
              TestSemantics.rootChild(
                id: 1,
                flags: SemanticsFlag.hasCheckedState.index |
                    SemanticsFlag.isChecked.index,
                label: label,
                rect: TestSemantics.fullScreen,
              ),
              // IDs 2 and 3 are used up by the nodes that get merged in
              TestSemantics.rootChild(
                id: 4,
                flags: SemanticsFlag.hasCheckedState.index |
                    SemanticsFlag.isChecked.index,
                label: label,
                rect: TestSemantics.fullScreen,
              ),
              // IDs 5 and 6 are used up by the nodes that get merged in
            ],
          ),
        ));

    semantics.dispose();
  });
}
