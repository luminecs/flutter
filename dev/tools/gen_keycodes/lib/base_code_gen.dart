import 'dart:io';
import 'logical_key_data.dart';

import 'physical_key_data.dart';

String _injectDictionary(String template, Map<String, String> dictionary) {
  String result = template;
  for (final String key in dictionary.keys) {
    result = result.replaceAll('@@@$key@@@', dictionary[key] ?? '@@@$key@@@');
  }
  return result;
}

abstract class BaseCodeGenerator {
  BaseCodeGenerator(this.keyData, this.logicalData);

  String get templatePath;

  Map<String, String> mappings();

  String generate() {
    final String template = File(templatePath).readAsStringSync();
    return _injectDictionary(template, mappings());
  }

  final PhysicalKeyData keyData;

  final LogicalKeyData logicalData;
}

abstract class PlatformCodeGenerator extends BaseCodeGenerator {
  PlatformCodeGenerator(super.keyData, super.logicalData);

  String outputPath(String platform);

  static String engineRoot = '';
}