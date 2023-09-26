import 'package:test/test.dart';

export 'package:test/test.dart' hide isInstanceOf;

TypeMatcher<T> isInstanceOf<T>() => isA<T>();
