import 'dart:async';

import 'package:flutter/material.dart';

enum TestStatus { ok, pending, failed, complete }

typedef TestStep = Future<TestStepResult> Function();

const String nothing = '-';

class TestStepResult {
  const TestStepResult(this.name, this.description, this.status);

  factory TestStepResult.fromSnapshot(AsyncSnapshot<TestStepResult> snapshot) {
    switch (snapshot.connectionState) {
      case ConnectionState.none:
        return const TestStepResult('Not started', nothing, TestStatus.ok);
      case ConnectionState.waiting:
        return const TestStepResult('Executing', nothing, TestStatus.pending);
      case ConnectionState.done:
        if (snapshot.hasData) {
          return snapshot.data!;
        } else {
          final Object? result = snapshot.error;
          return result! as TestStepResult;
        }
      case ConnectionState.active:
        throw 'Unsupported state ${snapshot.connectionState}';
    }
  }

  final String name;
  final String description;
  final TestStatus status;

  static const TextStyle normal = TextStyle(height: 1.0);
  static const TextStyle bold = TextStyle(fontWeight: FontWeight.bold, height: 1.0);
  static const TestStepResult complete = TestStepResult(
    'Test complete',
    nothing,
    TestStatus.complete,
  );

  Widget asWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Step: $name', style: bold),
        Text(description, style: normal),
        const Text(' ', style: normal),
        Text(
          status.toString().substring('TestStatus.'.length),
          key: ValueKey<String>(
              status == TestStatus.pending ? 'nostatus' : 'status'),
          style: bold,
        ),
      ],
    );
  }
}