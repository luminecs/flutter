
import 'project.dart';

class ProjectWithEarlyError extends Project {

  @override
  final String pubspec = '''
  name: test
  environment:
    sdk: '>=3.2.0-0 <4.0.0'

  dependencies:
    flutter:
      sdk: flutter
  ''';

  @override
  final String main = r'''
  import 'dart:async';

  import 'package:flutter/material.dart';

  Future<void> main() async {
    while (true) {
      runApp(MyApp());
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  class MyApp extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
      throw FormatException();
    }
  }
  ''';

}