import 'project.dart';

class CompileErrorProject extends Project {

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
    this code does not compile
  }
  ''';
}