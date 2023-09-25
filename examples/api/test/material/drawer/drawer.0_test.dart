// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/drawer/drawer.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Navigation bar updates destination on tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.DrawerApp(),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    expect(find.text('Page: '), findsOneWidget);

    await tester.tap(find.ancestor(of: find.text('Messages'), matching: find.byType(InkWell)));
    await tester.pumpAndSettle();
    expect(find.text('Page: Messages'), findsOneWidget);

    await tester.tap(find.ancestor(of: find.text('Profile'), matching: find.byType(InkWell)));
    await tester.pumpAndSettle();
    expect(find.text('Page: Profile'), findsOneWidget);

    await tester.tap(find.ancestor(of: find.text('Settings'), matching: find.byType(InkWell)));
    await tester.pumpAndSettle();
    expect(find.text('Page: Settings'), findsOneWidget);
  });
}