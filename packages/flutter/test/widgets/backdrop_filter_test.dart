
// This file is run as part of a reduced test set in CI on Mac and Windows
// machines.
@Tags(<String>['reduced-test-set'])
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  testWidgetsWithLeakTracking("Material2 - BackdropFilter's cull rect does not shrink", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Text('0 0 ' * 10000),
              Center(
                // ClipRect needed for filtering the 200x200 area instead of the
                // whole screen.
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5.0,
                      sigmaY: 5.0,
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      width: 200.0,
                      height: 200.0,
                      child: const Text('Hello World'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('m2_backdrop_filter_test.cull_rect.png'),
    );
  });

  testWidgetsWithLeakTracking("Material3 - BackdropFilter's cull rect does not shrink", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Text('0 0 ' * 10000),
              Center(
                // ClipRect needed for filtering the 200x200 area instead of the
                // whole screen.
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5.0,
                      sigmaY: 5.0,
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      width: 200.0,
                      height: 200.0,
                      child: const Text('Hello World'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('m3_backdrop_filter_test.cull_rect.png'),
    );
  });

  testWidgetsWithLeakTracking('Material2 - BackdropFilter blendMode on saveLayer', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: Opacity(
            opacity: 0.9,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Text('0 0 ' * 10000),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  // ClipRect needed for filtering the 200x200 area instead of the
                  // whole screen.
                  children: <Widget>[
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 5.0,
                          sigmaY: 5.0,
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          width: 200.0,
                          height: 200.0,
                          color: Colors.yellow.withAlpha(0x7),
                        ),
                      ),
                    ),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 5.0,
                          sigmaY: 5.0,
                        ),
                        blendMode: BlendMode.src,
                        child: Container(
                          alignment: Alignment.center,
                          width: 200.0,
                          height: 200.0,
                          color: Colors.yellow.withAlpha(0x7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('m2_backdrop_filter_test.saveLayer.blendMode.png'),
    );
  });

  testWidgetsWithLeakTracking('Material3 - BackdropFilter blendMode on saveLayer', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Opacity(
            opacity: 0.9,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Text('0 0 ' * 10000),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  // ClipRect needed for filtering the 200x200 area instead of the
                  // whole screen.
                  children: <Widget>[
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 5.0,
                          sigmaY: 5.0,
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          width: 200.0,
                          height: 200.0,
                          color: Colors.yellow.withAlpha(0x7),
                        ),
                      ),
                    ),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 5.0,
                          sigmaY: 5.0,
                        ),
                        blendMode: BlendMode.src,
                        child: Container(
                          alignment: Alignment.center,
                          width: 200.0,
                          height: 200.0,
                          color: Colors.yellow.withAlpha(0x7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('m3_backdrop_filter_test.saveLayer.blendMode.png'),
    );
  });
}