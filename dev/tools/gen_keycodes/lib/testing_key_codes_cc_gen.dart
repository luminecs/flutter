
import 'package:path/path.dart' as path;

import 'base_code_gen.dart';
import 'logical_key_data.dart';
import 'physical_key_data.dart';
import 'utils.dart';

String _toUpperCamel(String lowerCamel) {
  return lowerCamel.substring(0, 1).toUpperCase() + lowerCamel.substring(1);
}

class KeyCodesCcGenerator extends BaseCodeGenerator {
  KeyCodesCcGenerator(super.keyData, super.logicalData);

  String get _physicalDefinitions {
    final OutputLines<int> lines = OutputLines<int>('Physical Key list');
    for (final PhysicalKeyEntry entry in keyData.entries) {
      lines.add(entry.usbHidCode, '''
constexpr uint64_t kPhysical${_toUpperCamel(entry.constantName)} = ${toHex(entry.usbHidCode)};''');
    }
    return lines.sortedJoin().trimRight();
  }

  String get _logicalDefinitions {
    final OutputLines<int> lines = OutputLines<int>('Logical Key list', behavior: DeduplicateBehavior.kSkip);
    for (final LogicalKeyEntry entry in logicalData.entries) {
      lines.add(entry.value, '''
constexpr uint64_t kLogical${_toUpperCamel(entry.constantName)} = ${toHex(entry.value, digits: 11)};''');
    }
    return lines.sortedJoin().trimRight();
  }

  @override
  String get templatePath => path.join(dataRoot, 'key_codes_h.tmpl');

  @override
  Map<String, String> mappings() {
    return <String, String>{
      'LOGICAL_KEY_DEFINITIONS': _logicalDefinitions,
      'PHYSICAL_KEY_DEFINITIONS': _physicalDefinitions,
    };
  }
}