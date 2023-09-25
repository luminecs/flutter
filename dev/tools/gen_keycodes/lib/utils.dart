
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import 'constants.dart';

final Directory flutterRoot = Directory(path.dirname(Platform.script.toFilePath())).parent.parent.parent.parent;
String get dataRoot => testDataRoot ?? _dataRoot;
String _dataRoot = path.join(flutterRoot.path, 'dev', 'tools', 'gen_keycodes', 'data');

@visibleForTesting
String? testDataRoot;

String shoutingToUpperCamel(String shouting) {
  final RegExp initialLetter = RegExp(r'(?:_|^)([^_])([^_]*)');
  final String snake = shouting.toLowerCase();
  final String result = snake.replaceAllMapped(initialLetter, (Match match) {
    return match.group(1)!.toUpperCase() + match.group(2)!.toLowerCase();
  });
  return result;
}

String upperCamelToLowerCamel(String upperCamel) {
  final RegExp initialGroup = RegExp(r'^([A-Z]([A-Z]*|[^A-Z]*))([A-Z]([^A-Z]|$)|$)');
  return upperCamel.replaceFirstMapped(initialGroup, (Match match) {
    return match.group(1)!.toLowerCase() + (match.group(3) ?? '');
  });
}

String lowerCamelToUpperCamel(String lowerCamel) {
  return lowerCamel.substring(0, 1).toUpperCase() + lowerCamel.substring(1);
}

const List<String> kDartReservedWords = <String>[
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'rethrow',
  'return',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'while',
  'with',
  'yield',
];

String toHex(int? value, {int digits = 8}) {
  if (value == null) {
    return 'null';
  }
  return '0x${value.toRadixString(16).padLeft(digits, '0')}';
}

int getHex(String input) {
  return int.parse(input, radix: 16);
}

String wrapString(String input, {required String prefix}) {
  final int wrapWidth = 80 - prefix.length;
  final StringBuffer result = StringBuffer();
  final List<String> words = input.split(RegExp(r'\s+'));
  String currentLine = words.removeAt(0);
  for (final String word in words) {
    if ((currentLine.length + word.length) < wrapWidth) {
      currentLine += ' $word';
    } else {
      result.writeln('$prefix$currentLine');
      currentLine = word;
    }
  }
  if (currentLine.isNotEmpty) {
    result.writeln('$prefix$currentLine');
  }
  return result.toString();
}

void zipStrict<T1, T2>(Iterable<T1> list1, Iterable<T2> list2, void Function(T1, T2) fn) {
  assert(list1.length == list2.length);
  final Iterator<T1> it1 = list1.iterator;
  final Iterator<T2> it2 = list2.iterator;
  while (it1.moveNext()) {
    it2.moveNext();
    fn(it1.current, it2.current);
  }
}

Map<String, String> parseMapOfString(String jsonString) {
  return (json.decode(jsonString) as Map<String, dynamic>).cast<String, String>();
}

Map<String, List<String>> parseMapOfListOfString(String jsonString) {
  final Map<String, List<dynamic>> dynamicMap = (json.decode(jsonString) as Map<String, dynamic>).cast<String, List<dynamic>>();
  return dynamicMap.map<String, List<String>>((String key, List<dynamic> value) {
    return MapEntry<String, List<String>>(key, value.cast<String>());
  });
}

Map<String, List<String?>> parseMapOfListOfNullableString(String jsonString) {
  final Map<String, List<dynamic>> dynamicMap = (json.decode(jsonString) as Map<String, dynamic>).cast<String, List<dynamic>>();
  return dynamicMap.map<String, List<String?>>((String key, List<dynamic> value) {
    return MapEntry<String, List<String?>>(key, value.cast<String?>());
  });
}

Map<String, bool> parseMapOfBool(String jsonString) {
  return (json.decode(jsonString) as Map<String, dynamic>).cast<String, bool>();
}

Map<String, String> reverseMapOfListOfString(Map<String, List<String>> inMap, void Function(String fromValue, String newToValue) onDuplicate) {
  final Map<String, String> result = <String, String>{};
  inMap.forEach((String fromValue, List<String> toValues) {
    for (final String toValue in toValues) {
      if (result.containsKey(toValue)) {
        onDuplicate(fromValue, toValue);
        continue;
      }
      result[toValue] = fromValue;
    }
  });
  return result;
}

Map<String, dynamic> removeEmptyValues(Map<String, dynamic> map) {
  return map..removeWhere((String key, dynamic value) {
    if (value == null) {
      return true;
    }
    if (value is Map<String, dynamic>) {
      final Map<String, dynamic> regularizedMap = removeEmptyValues(value);
      return regularizedMap.isEmpty;
    }
    if (value is Iterable<dynamic>) {
      return value.isEmpty;
    }
    return false;
  });
}

void addNameValue(List<String> names, List<int> values, String name, int value) {
  final int foundIndex = values.indexOf(value);
  if (foundIndex == -1) {
    names.add(name);
    values.add(value);
  } else {
    if (!RegExp(r'(^|, )abc1($|, )').hasMatch(name)) {
      names[foundIndex] = '${names[foundIndex]}, $name';
    }
  }
}

enum DeduplicateBehavior {
  // Warn the duplicate entry.
  kWarn,

  // Skip the latter duplicate entry.
  kSkip,

  // Keep all duplicate entries.
  kKeep,
}

class OutputLine<T extends Comparable<Object>> {
  OutputLine(this.key, String value)
    : values = <String>[value];

  final T key;
  final List<String> values;
}

class OutputLines<T extends Comparable<Object>> {
  OutputLines(this.mapName, {this.behavior = DeduplicateBehavior.kWarn});

  final DeduplicateBehavior behavior;

  final String mapName;

  final Map<T, OutputLine<T>> lines = <T, OutputLine<T>>{};

  void add(T key, String line) {
    final OutputLine<T>? existing = lines[key];
    if (existing != null) {
      switch (behavior) {
        case DeduplicateBehavior.kWarn:
          print('Warn: Request to add $key to map "$mapName" as:\n    $line\n  but it already exists as:\n    ${existing.values[0]}');
          return;
        case DeduplicateBehavior.kSkip:
          return;
        case DeduplicateBehavior.kKeep:
          existing.values.add(line);
          return;
      }
    }
    lines[key] = OutputLine<T>(key, line);
  }

  String join() {
    return lines.values.map((OutputLine<T> line) => line.values.join('\n')).join('\n');
  }

  String sortedJoin() {
    return (lines.values.toList()
      ..sort((OutputLine<T> a, OutputLine<T> b) => a.key.compareTo(b.key)))
      .map((OutputLine<T> line) => line.values.join('\n'))
      .join('\n');
  }
}

int toPlane(int value, int plane) {
  return (value & kValueMask.value) + (plane & kPlaneMask.value);
}

int getPlane(int value) {
  return value & kPlaneMask.value;
}