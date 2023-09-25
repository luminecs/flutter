
import 'package:path/path.dart' as path;

import 'base_code_gen.dart';
import 'constants.dart';
import 'logical_key_data.dart';
import 'physical_key_data.dart';
import 'utils.dart';


class AndroidCodeGenerator extends PlatformCodeGenerator {
  AndroidCodeGenerator(super.keyData, super.logicalData);

  String get _androidKeyCodeMap {
    final StringBuffer androidKeyCodeMap = StringBuffer();
    for (final LogicalKeyEntry entry in logicalData.entries) {
      for (final int code in entry.androidValues) {
        androidKeyCodeMap.writeln('          put(${toHex(code, digits: 10)}L, ${toHex(entry.value, digits: 10)}L); // ${entry.constantName}');
      }
    }
    return androidKeyCodeMap.toString().trimRight();
  }

  String get _androidScanCodeMap {
    final StringBuffer androidScanCodeMap = StringBuffer();
    for (final PhysicalKeyEntry entry in keyData.entries) {
      for (final int code in entry.androidScanCodes.cast<int>()) {
        androidScanCodeMap.writeln('          put(${toHex(code, digits: 10)}L, ${toHex(entry.usbHidCode, digits: 10)}L); // ${entry.constantName}');
      }
    }
    return androidScanCodeMap.toString().trimRight();
  }

  String get _pressingGoals {
    final OutputLines<int> lines = OutputLines<int>('Android pressing goals');
    const Map<String, List<String>> goalsSource = <String, List<String>>{
      'SHIFT': <String>['ShiftLeft', 'ShiftRight'],
      'CTRL': <String>['ControlLeft', 'ControlRight'],
      'ALT': <String>['AltLeft', 'AltRight'],
    };
    goalsSource.forEach((String flagName, List<String> keys) {
      int? lineId;
      final List<String> keysString = keys.map((String keyName) {
        final PhysicalKeyEntry physicalKey = keyData.entryByName(keyName);
        final LogicalKeyEntry logicalKey = logicalData.entryByName(keyName);
        lineId ??= physicalKey.usbHidCode;
        return '              new KeyPair(${toHex(physicalKey.usbHidCode)}L, '
          '${toHex(logicalKey.value, digits: 10)}L), // ${physicalKey.name}';
      }).toList();
      lines.add(lineId!,
          '        new PressingGoal(\n'
          '            KeyEvent.META_${flagName}_ON,\n'
          '            new KeyPair[] {\n'
          '${keysString.join('\n')}\n'
          '            }),');
    });
    return lines.sortedJoin().trimRight();
  }

  String get _togglingGoals {
    final OutputLines<int> lines = OutputLines<int>('Android toggling goals');
    const Map<String, String> goalsSource = <String, String>{
      'CAPS_LOCK': 'CapsLock',
    };
    goalsSource.forEach((String flagName, String keyName) {
      final PhysicalKeyEntry physicalKey = keyData.entryByName(keyName);
      final LogicalKeyEntry logicalKey = logicalData.entryByName(keyName);
      lines.add(physicalKey.usbHidCode,
          '      new TogglingGoal(KeyEvent.META_${flagName}_ON, '
          '${toHex(physicalKey.usbHidCode)}L, '
          '${toHex(logicalKey.value, digits: 10)}L),');
    });
    return lines.sortedJoin().trimRight();
  }

  String get _maskConstants {
    final StringBuffer buffer = StringBuffer();
    const List<MaskConstant> maskConstants = <MaskConstant>[
      kValueMask,
      kUnicodePlane,
      kAndroidPlane,
    ];
    for (final MaskConstant constant in maskConstants) {
      buffer.writeln('  public static final long k${constant.upperCamelName} = ${toHex(constant.value, digits: 11)}L;');
    }
    return buffer.toString().trimRight();
  }

  @override
  String get templatePath => path.join(dataRoot, 'android_keyboard_map_java.tmpl');

  @override
  String outputPath(String platform) => path.join(PlatformCodeGenerator.engineRoot, 'shell', 'platform',
      path.join('android', 'io', 'flutter', 'embedding', 'android', 'KeyboardMap.java'));

  @override
  Map<String, String> mappings() {
    return <String, String>{
      'ANDROID_SCAN_CODE_MAP': _androidScanCodeMap,
      'ANDROID_KEY_CODE_MAP': _androidKeyCodeMap,
      'PRESSING_GOALS': _pressingGoals,
      'TOGGLING_GOALS': _togglingGoals,
      'MASK_CONSTANTS': _maskConstants,
    };
  }
}