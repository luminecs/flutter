
import 'package:test/test.dart' hide isInstanceOf;

export 'package:test/test.dart' hide isInstanceOf;

TypeMatcher<T> isInstanceOf<T>() => isA<T>();