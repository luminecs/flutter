import 'package:path/path.dart' as path;

import 'base_code_gen.dart';
import 'constants.dart';
import 'logical_key_data.dart';
import 'physical_key_data.dart';
import 'utils.dart';

class WindowsCodeGenerator extends PlatformCodeGenerator {
  WindowsCodeGenerator(
    super.keyData,
    super.logicalData,
    String scancodeToLogical,
  ) : _scancodeToLogical = parseMapOfString(scancodeToLogical);

  String get _windowsScanCodeMap {
    final OutputLines<int> lines = OutputLines<int>('Windows scancode map');
    for (final PhysicalKeyEntry entry in keyData.entries) {
      if (entry.windowsScanCode != null) {
        lines.add(entry.windowsScanCode!,
            '        {${toHex(entry.windowsScanCode)}, ${toHex(entry.usbHidCode)}},  // ${entry.constantName}');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  String get _windowsLogicalKeyCodeMap {
    final OutputLines<int> lines = OutputLines<int>('Windows logical map');
    for (final LogicalKeyEntry entry in logicalData.entries) {
      zipStrict(
        entry.windowsValues,
        entry.windowsNames,
        (int windowsValue, String windowsName) {
          lines.add(
              windowsValue,
              '        {${toHex(windowsValue)}, ${toHex(entry.value, digits: 11)}},  '
              '// $windowsName -> ${entry.constantName}');
        },
      );
    }
    return lines.sortedJoin().trimRight();
  }

  String get _scanCodeToLogicalMap {
    final OutputLines<int> lines =
        OutputLines<int>('Windows scancode to logical map');
    _scancodeToLogical.forEach((String scanCodeName, String logicalName) {
      final PhysicalKeyEntry physicalEntry = keyData.entryByName(scanCodeName);
      final LogicalKeyEntry logicalEntry = logicalData.entryByName(logicalName);
      lines.add(
          physicalEntry.windowsScanCode!,
          '        {${toHex(physicalEntry.windowsScanCode)}, ${toHex(logicalEntry.value, digits: 11)}},  '
          '// ${physicalEntry.constantName} -> ${logicalEntry.constantName}');
    });
    return lines.sortedJoin().trimRight();
  }

  final Map<String, String> _scancodeToLogical;

  String get _maskConstants {
    final StringBuffer buffer = StringBuffer();
    const List<MaskConstant> maskConstants = <MaskConstant>[
      kValueMask,
      kUnicodePlane,
      kWindowsPlane,
    ];
    for (final MaskConstant constant in maskConstants) {
      buffer.writeln(
          'const uint64_t KeyboardKeyEmbedderHandler::${constant.lowerCamelName} = ${toHex(constant.value, digits: 11)};');
    }
    return buffer.toString().trimRight();
  }

  @override
  String get templatePath =>
      path.join(dataRoot, 'windows_flutter_key_map_cc.tmpl');

  @override
  String outputPath(String platform) => path.join(
      PlatformCodeGenerator.engineRoot,
      'shell',
      'platform',
      'windows',
      'flutter_key_map.g.cc');

  @override
  Map<String, String> mappings() {
    return <String, String>{
      'WINDOWS_SCAN_CODE_MAP': _windowsScanCodeMap,
      'WINDOWS_SCAN_CODE_TO_LOGICAL_MAP': _scanCodeToLogicalMap,
      'WINDOWS_KEY_CODE_MAP': _windowsLogicalKeyCodeMap,
      'MASK_CONSTANTS': _maskConstants,
    };
  }
}
