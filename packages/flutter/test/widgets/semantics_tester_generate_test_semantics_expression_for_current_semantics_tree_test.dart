// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('!chrome')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import 'semantics_tester.dart';

void main() {
  group('generateTestSemanticsExpressionForCurrentSemanticsTree', () {
    _tests();
  });
}

void _tests() {
  setUp(() {
    debugResetSemanticsIdCounter();
  });

  Future<void> pumpTestWidget(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ListView(
        children: <Widget>[
          const Text('Plain text'),
          Semantics(
            selected: true,
            checked: true,
            onTap: () { },
            onDecrease: () { },
            value: 'test-value',
            increasedValue: 'test-increasedValue',
            decreasedValue: 'test-decreasedValue',
            hint: 'test-hint',
            textDirection: TextDirection.rtl,
            child: const Text('Interactive text'),
          ),
        ],
      ),
    ));
  }

  // This test generates code using generateTestSemanticsExpressionForCurrentSemanticsTree
  // then compares it to the code used in the 'generated code is correct' test
  // below. When you update the implementation of generateTestSemanticsExpressionForCurrentSemanticsTree
  // also update this code to reflect the new output.
  //
  // This test is flexible w.r.t. leading and trailing whitespace.
  testWidgetsWithLeakTracking('generates code', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);
    await pumpTestWidget(tester);
    final String code = semantics
      .generateTestSemanticsExpressionForCurrentSemanticsTree(DebugSemanticsDumpOrder.inverseHitTest)
      .split('\n')
      .map<String>((String line) => line.trim())
      .join('\n')
      .trim();

    File? findThisTestFile(Directory directory) {
      for (final FileSystemEntity entity in directory.listSync()) {
        if (entity is Directory) {
          final File? childSearch = findThisTestFile(entity);
          if (childSearch != null) {
            return childSearch;
          }
        } else if (entity is File && entity.path.endsWith('semantics_tester_generate_test_semantics_expression_for_current_semantics_tree_test.dart')) {
          return entity;
        }
      }
      return null;
    }

    final File thisTestFile = findThisTestFile(Directory.current)!;
    expect(thisTestFile, isNotNull);
    String expectedCode = thisTestFile.readAsStringSync();
    expectedCode = expectedCode.substring(
      expectedCode.indexOf('v' * 12) + 12,
      expectedCode.indexOf('^' * 12) - 3,
    )
      .split('\n')
      .map<String>((String line) => line.trim())
      .join('\n')
      .trim();
    semantics.dispose();
    expect('$code,', expectedCode);
  });

  testWidgetsWithLeakTracking('generated code is correct', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);
    await pumpTestWidget(tester);
    expect(
      semantics,
      hasSemantics(
        // The code below delimited by "v" and "^" characters is generated by
        // generateTestSemanticsExpressionForCurrentSemanticsTree function.
        // You must update it when changing the output generated by
        // generateTestSemanticsExpressionForCurrentSemanticsTree. Otherwise,
        // the test 'generates code', defined above, will fail.
        // vvvvvvvvvvvv
        TestSemantics.root(
          children: <TestSemantics>[
            TestSemantics(
              id: 1,
              textDirection: TextDirection.ltr,
              children: <TestSemantics>[
                TestSemantics(
                  id: 2,
                  children: <TestSemantics>[
                    TestSemantics(
                      id: 3,
                      flags: <SemanticsFlag>[SemanticsFlag.scopesRoute],
                      children: <TestSemantics>[
                        TestSemantics(
                          id: 4,
                          children: <TestSemantics>[
                            TestSemantics(
                              id: 7,
                              flags: <SemanticsFlag>[SemanticsFlag.hasImplicitScrolling],
                              children: <TestSemantics>[
                                TestSemantics(
                                  id: 5,
                                  tags: <SemanticsTag>[const SemanticsTag('RenderViewport.twoPane')],
                                  label: 'Plain text',
                                  textDirection: TextDirection.ltr,
                                ),
                                TestSemantics(
                                  id: 6,
                                  tags: <SemanticsTag>[const SemanticsTag('RenderViewport.twoPane')],
                                  flags: <SemanticsFlag>[SemanticsFlag.hasCheckedState, SemanticsFlag.isChecked, SemanticsFlag.isSelected],
                                  actions: <SemanticsAction>[SemanticsAction.tap, SemanticsAction.decrease],
                                  label: '\u202aInteractive text\u202c',
                                  value: 'test-value',
                                  increasedValue: 'test-increasedValue',
                                  decreasedValue: 'test-decreasedValue',
                                  hint: 'test-hint',
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // ^^^^^^^^^^^^
        ignoreRect: true,
        ignoreTransform: true,
        ignoreId: true,
      ),
    );
    semantics.dispose();
  });
}