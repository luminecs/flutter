import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import 'semantics_tester.dart';

void main() {
  setUp(() {
    debugResetSemanticsIdCounter();
  });

  testWidgetsWithLeakTracking('MergeSemantics', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    // not merged
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: <Widget>[
            Semantics(
              container: true,
              child: const Text('test1'),
            ),
            Semantics(
              container: true,
              child: const Text('test2'),
            ),
          ],
        ),
      ),
    );

    expect(semantics, hasSemantics(
      TestSemantics.root(
        children: <TestSemantics>[
          TestSemantics.rootChild(
            id: 1,
            label: 'test1',
          ),
          TestSemantics.rootChild(
            id: 2,
            label: 'test2',
          ),
        ],
      ),
      ignoreRect: true,
      ignoreTransform: true,
    ));

    // merged
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MergeSemantics(
          child: Row(
            children: <Widget>[
              Semantics(
                container: true,
                child: const Text('test1'),
              ),
              Semantics(
                container: true,
                child: const Text('test2'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(semantics, hasSemantics(
      TestSemantics.root(
        children: <TestSemantics>[
          TestSemantics.rootChild(
            id: 3,
            label: 'test1\ntest2',
          ),
        ],
      ),
      ignoreRect: true,
      ignoreTransform: true,
    ));

    // not merged
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: <Widget>[
            Semantics(
              container: true,
              child: const Text('test1'),
            ),
            Semantics(
              container: true,
              child: const Text('test2'),
            ),
          ],
        ),
      ),
    );

    expect(semantics, hasSemantics(
      TestSemantics.root(
        children: <TestSemantics>[
          TestSemantics.rootChild(id: 6, label: 'test1'),
          TestSemantics.rootChild(id: 7, label: 'test2'),
        ],
      ),
      ignoreRect: true,
      ignoreTransform: true,
    ));

    semantics.dispose();
  });

  testWidgetsWithLeakTracking('MergeSemantics works if other nodes are implicitly merged into its node', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MergeSemantics(
          child: Semantics(
            selected: true, // this is implicitly merged into the MergeSemantics node
            child: Row(
              children: <Widget>[
                Semantics(
                  container: true,
                  child: const Text('test1'),
                ),
                Semantics(
                  container: true,
                  child: const Text('test2'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(semantics, hasSemantics(
      TestSemantics.root(
          children: <TestSemantics>[
            TestSemantics.rootChild(
              id: 1,
              flags: <SemanticsFlag>[
                SemanticsFlag.isSelected,
              ],
              label: 'test1\ntest2',
            ),
          ],
      ),
      ignoreRect: true,
      ignoreTransform: true,
    ));

    semantics.dispose();
  });
}