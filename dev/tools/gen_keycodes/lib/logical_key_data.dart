
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'constants.dart';
import 'physical_key_data.dart';
import 'utils.dart';

bool _isControlCharacter(int codeUnit) {
  return (codeUnit <= 0x1f && codeUnit >= 0x00) || (codeUnit >= 0x7f && codeUnit <= 0x9f);
}

class _ModifierPair {
  const _ModifierPair(this.left, this.right);

  final String left;
  final String right;
}

// Return map[key1][key2] as a non-nullable List<T>, where both map[key1] or
// map[key1][key2] might be null.
List<T> _getGrandchildList<T>(Map<String, dynamic> map, String key1, String key2) {
  final dynamic value = (map[key1] as Map<String, dynamic>?)?[key2];
  final List<dynamic>? dynamicNullableList = value as List<dynamic>?;
  final List<dynamic> dynamicList = dynamicNullableList ?? <dynamic>[];
  return dynamicList.cast<T>();
}

class LogicalKeyData {
  factory LogicalKeyData(
    String chromiumKeys,
    String gtkKeyCodeHeader,
    String gtkNameMap,
    String windowsKeyCodeHeader,
    String windowsNameMap,
    String androidKeyCodeHeader,
    String androidNameMap,
    String macosLogicalToPhysical,
    String iosLogicalToPhysical,
    String glfwHeaderFile,
    String glfwNameMap,
    PhysicalKeyData physicalKeyData,
  ) {
    final Map<String, LogicalKeyEntry> data = _readKeyEntries(chromiumKeys);
    _readWindowsKeyCodes(data, windowsKeyCodeHeader, parseMapOfListOfString(windowsNameMap));
    _readGtkKeyCodes(data, gtkKeyCodeHeader, parseMapOfListOfString(gtkNameMap));
    _readAndroidKeyCodes(data, androidKeyCodeHeader, parseMapOfListOfString(androidNameMap));
    _readMacOsKeyCodes(data, physicalKeyData, parseMapOfListOfString(macosLogicalToPhysical));
    _readIosKeyCodes(data, physicalKeyData, parseMapOfListOfString(iosLogicalToPhysical));
    _readFuchsiaKeyCodes(data, physicalKeyData);
    _readGlfwKeyCodes(data, glfwHeaderFile, parseMapOfListOfString(glfwNameMap));
    // Sort entries by value
    final List<MapEntry<String, LogicalKeyEntry>> sortedEntries = data.entries.toList()..sort(
      (MapEntry<String, LogicalKeyEntry> a, MapEntry<String, LogicalKeyEntry> b) =>
        LogicalKeyEntry.compareByValue(a.value, b.value),
    );
    data
      ..clear()
      ..addEntries(sortedEntries);
    return LogicalKeyData._(data);
  }

  factory LogicalKeyData.fromJson(Map<String, dynamic> contentMap) {
    final Map<String, LogicalKeyEntry> data = <String, LogicalKeyEntry>{};
    data.addEntries(contentMap.values.map((dynamic value) {
      final LogicalKeyEntry entry = LogicalKeyEntry.fromJsonMapEntry(value as Map<String, dynamic>);
      return MapEntry<String, LogicalKeyEntry>(entry.name, entry);
    }));
    return LogicalKeyData._(data);
  }

  LogicalKeyData._(this._data);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> outputMap = <String, dynamic>{};
    for (final LogicalKeyEntry entry in _data.values) {
      outputMap[entry.name] = entry.toJson();
    }
    return outputMap;
  }

  LogicalKeyEntry entryByName(String name) {
    assert(_data.containsKey(name),
        'Unable to find logical entry by name $name.');
    return _data[name]!;
  }

  Iterable<LogicalKeyEntry> get entries => _data.values;

  // Keys mapped from their names.
  final Map<String, LogicalKeyEntry> _data;

  static Map<String, LogicalKeyEntry> _readKeyEntries(String input) {
    final Map<int, LogicalKeyEntry> dataByValue = <int, LogicalKeyEntry>{};
    final RegExp domKeyRegExp = RegExp(
      r'(?<source>DOM|FLUTTER)_KEY_(?<kind>UNI|MAP)\s*\(\s*'
      r'"(?<name>[^\s]+?)",\s*'
      r'(?<enum>[^\s]+?),\s*'
      r"(?:0[xX](?<unicode>[a-fA-F0-9]+)|'(?<char>.)')\s*"
      r'\)',
      // Multiline is necessary because some definitions spread across
      // multiple lines.
      multiLine: true,
    );
    final RegExp commentRegExp = RegExp(r'//.*$', multiLine: true);
    input = input.replaceAll(commentRegExp, '');
    for (final RegExpMatch match in domKeyRegExp.allMatches(input)) {
      final String source = match.namedGroup('source')!;
      final String webName = match.namedGroup('name')!;
      // ".AltGraphLatch"  is consumed internally and not expressed to the Web.
      if (webName.startsWith('.')) {
        continue;
      }
      final String name = LogicalKeyEntry.computeName(webName.replaceAll(RegExp('[^A-Za-z0-9]'), ''));
      final int value = match.namedGroup('unicode') != null ?
        getHex(match.namedGroup('unicode')!) :
        match.namedGroup('char')!.codeUnitAt(0);
      final String? keyLabel = (match.namedGroup('kind')! == 'UNI' && !_isControlCharacter(value)) ?
        String.fromCharCode(value) : null;
      // Skip modifier keys from DOM. They will be added with supplemental data.
      if (_chromeModifiers.containsKey(name) && source == 'DOM') {
        continue;
      }

      final bool isPrintable = keyLabel != null;
      final int entryValue = toPlane(value, _sourceToPlane(source, isPrintable));
      final LogicalKeyEntry entry = dataByValue.putIfAbsent(entryValue, () =>
        LogicalKeyEntry.fromName(
          value: entryValue,
          name: name,
          keyLabel: keyLabel,
        ),
      );
      if (source == 'DOM' && !isPrintable) {
        entry.webNames.add(webName);
      }
    }
    return Map<String, LogicalKeyEntry>.fromEntries(
      dataByValue.values.map((LogicalKeyEntry entry) =>
        MapEntry<String, LogicalKeyEntry>(entry.name, entry),
      ),
    );
  }

  static void _readMacOsKeyCodes(
    Map<String, LogicalKeyEntry> data,
    PhysicalKeyData physicalKeyData,
    Map<String, List<String>> logicalToPhysical,
  ) {
    final Map<String, String> physicalToLogical = reverseMapOfListOfString(logicalToPhysical,
        (String logicalKeyName, String physicalKeyName) { print('Duplicate logical key name $logicalKeyName for macOS'); });

    physicalToLogical.forEach((String physicalKeyName, String logicalKeyName) {
      final PhysicalKeyEntry physicalEntry = physicalKeyData.entryByName(physicalKeyName);
      assert(physicalEntry.macOSScanCode != null,
        'Physical entry $physicalKeyName does not have a macOSScanCode.');
      final LogicalKeyEntry? logicalEntry = data[logicalKeyName];
      assert(logicalEntry != null,
        'Unable to find logical entry by name $logicalKeyName.');
      logicalEntry!.macOSKeyCodeNames.add(physicalEntry.name);
      logicalEntry.macOSKeyCodeValues.add(physicalEntry.macOSScanCode!);
    });
  }

  static void _readIosKeyCodes(
    Map<String, LogicalKeyEntry> data,
    PhysicalKeyData physicalKeyData,
    Map<String, List<String>> logicalToPhysical,
  ) {
    final Map<String, String> physicalToLogical = reverseMapOfListOfString(logicalToPhysical,
        (String logicalKeyName, String physicalKeyName) { print('Duplicate logical key name $logicalKeyName for iOS'); });

    physicalToLogical.forEach((String physicalKeyName, String logicalKeyName) {
      final PhysicalKeyEntry physicalEntry = physicalKeyData.entryByName(physicalKeyName);
      assert(physicalEntry.iOSScanCode != null,
        'Physical entry $physicalKeyName does not have an iosScanCode.');
      final LogicalKeyEntry? logicalEntry = data[logicalKeyName];
      assert(logicalEntry != null,
        'Unable to find logical entry by name $logicalKeyName.');
      logicalEntry!.iOSKeyCodeNames.add(physicalEntry.name);
      logicalEntry.iOSKeyCodeValues.add(physicalEntry.iOSScanCode!);
    });
  }

  static void _readGtkKeyCodes(Map<String, LogicalKeyEntry> data, String headerFile, Map<String, List<String>> nameToGtkName) {
    final RegExp definedCodes = RegExp(
      r'#define '
      r'GDK_KEY_(?<name>[a-zA-Z0-9_]+)\s*'
      r'0x(?<value>[0-9a-f]+),?',
    );
    final Map<String, String> gtkNameToFlutterName = reverseMapOfListOfString(nameToGtkName,
        (String flutterName, String gtkName) { print('Duplicate GTK logical name $gtkName'); });

    for (final RegExpMatch match in definedCodes.allMatches(headerFile)) {
      final String gtkName = match.namedGroup('name')!;
      final String? name = gtkNameToFlutterName[gtkName];
      final int value = int.parse(match.namedGroup('value')!, radix: 16);
      if (name == null) {
        // print('Unmapped GTK logical entry $gtkName');
        continue;
      }

      final LogicalKeyEntry? entry = data[name];
      if (entry == null) {
        print('Invalid logical entry by name $name (from GTK $gtkName)');
        continue;
      }
      entry
        ..gtkNames.add(gtkName)
        ..gtkValues.add(value);
    }
  }

  static void _readWindowsKeyCodes(Map<String, LogicalKeyEntry> data, String headerFile, Map<String, List<String>> nameMap) {
    // The mapping from the Flutter name (e.g. "enter") to the Windows name (e.g.
    // "RETURN").
    final Map<String, String> nameToFlutterName  = reverseMapOfListOfString(nameMap,
        (String flutterName, String windowsName) { print('Duplicate Windows logical name $windowsName'); });

    final RegExp definedCodes = RegExp(
      r'define '
      r'VK_(?<name>[A-Z0-9_]+)\s*'
      r'(?<value>[A-Z0-9_x]+),?',
    );
    for (final RegExpMatch match in definedCodes.allMatches(headerFile)) {
      final String windowsName = match.namedGroup('name')!;
      final String? name = nameToFlutterName[windowsName];
      final int value = int.tryParse(match.namedGroup('value')!)!;
      if (name == null) {
        print('Unmapped Windows logical entry $windowsName');
        continue;
      }
      final LogicalKeyEntry? entry = data[name];
      if (entry == null) {
        print('Invalid logical entry by name $name (from Windows $windowsName)');
        continue;
      }
      addNameValue(
        entry.windowsNames,
        entry.windowsValues,
        windowsName,
        value,
      );
    }
  }

  static void _readAndroidKeyCodes(Map<String, LogicalKeyEntry> data, String headerFile, Map<String, List<String>> nameMap) {
    final Map<String, String> nameToFlutterName  = reverseMapOfListOfString(nameMap,
        (String flutterName, String androidName) { print('Duplicate Android logical name $androidName'); });

    final RegExp enumBlock = RegExp(r'enum\s*\{(.*)\};', multiLine: true);
    // Eliminate everything outside of the enum block.
    headerFile = headerFile.replaceAllMapped(enumBlock, (Match match) => match.group(1)!);
    final RegExp enumEntry = RegExp(
      r'AKEYCODE_(?<name>[A-Z0-9_]+)\s*'
      r'=\s*'
      r'(?<value>[0-9]+),?',
    );
    for (final RegExpMatch match in enumEntry.allMatches(headerFile)) {
      final String androidName = match.namedGroup('name')!;
      final String? name = nameToFlutterName[androidName];
      final int value = int.tryParse(match.namedGroup('value')!)!;
      if (name == null) {
        print('Unmapped Android logical entry $androidName');
        continue;
      }
      final LogicalKeyEntry? entry = data[name];
      if (entry == null) {
        print('Invalid logical entry by name $name (from Android $androidName)');
        continue;
      }
      entry
        ..androidNames.add(androidName)
        ..androidValues.add(value);
    }
  }

  static void _readFuchsiaKeyCodes(Map<String, LogicalKeyEntry> data, PhysicalKeyData physicalData) {
    for (final LogicalKeyEntry entry in data.values) {
      final int? value = (() {
        if (entry.value == 0) {
          return 0;
        }
        final String? keyLabel = printable[entry.constantName];
        if (keyLabel != null && !entry.constantName.startsWith('numpad')) {
          return toPlane(keyLabel.codeUnitAt(0), kUnicodePlane.value);
        } else {
          final PhysicalKeyEntry? physicalEntry = physicalData.tryEntryByName(entry.name);
          if (physicalEntry != null) {
            return toPlane(physicalEntry.usbHidCode, kFuchsiaPlane.value);
          }
        }
      })();
      if (value != null) {
        entry.fuchsiaValues.add(value);
      }
    }
  }

  static void _readGlfwKeyCodes(Map<String, LogicalKeyEntry> data, String headerFile, Map<String, List<String>> nameMap) {
    final Map<String, String> nameToFlutterName  = reverseMapOfListOfString(nameMap,
        (String flutterName, String glfwName) { print('Duplicate GLFW logical name $glfwName'); });

    // Only get the KEY definitions, ignore the rest (mouse, joystick, etc).
    final RegExp definedCodes = RegExp(
      r'define\s+'
      r'GLFW_KEY_(?<name>[A-Z0-9_]+)\s+'
      r'(?<value>[A-Z0-9_]+),?',
    );
    final Map<String, dynamic> replaced = <String, dynamic>{};
    for (final RegExpMatch match in definedCodes.allMatches(headerFile)) {
      final String name = match.namedGroup('name')!;
      final String value = match.namedGroup('value')!;
      replaced[name] = int.tryParse(value) ?? value.replaceAll('GLFW_KEY_', '');
    }
    final Map<String, int> glfwNameToKeyCode = <String, int>{};
    replaced.forEach((String key, dynamic value) {
      // Some definition values point to other definitions (e.g #define GLFW_KEY_LAST GLFW_KEY_MENU).
      if (value is String) {
        glfwNameToKeyCode[key] = replaced[value] as int;
      } else {
        glfwNameToKeyCode[key] = value as int;
      }
    });

    glfwNameToKeyCode.forEach((String glfwName, int value) {
      final String? name = nameToFlutterName[glfwName];
      if (name == null) {
        return;
      }
      final LogicalKeyEntry? entry = data[nameToFlutterName[glfwName]];
      if (entry == null) {
        print('Invalid logical entry by name $name (from GLFW $glfwName)');
        return;
      }
      addNameValue(
        entry.glfwNames,
        entry.glfwValues,
        glfwName,
        value,
      );
    });
  }

  // Map Web key to the pair of key names
  static final Map<String, _ModifierPair> _chromeModifiers = () {
    final String rawJson = File(path.join(dataRoot, 'chromium_modifiers.json',)).readAsStringSync();
    return (json.decode(rawJson) as Map<String, dynamic>).map((String key, dynamic value) {
      final List<dynamic> pair = value as List<dynamic>;
      return MapEntry<String, _ModifierPair>(key, _ModifierPair(pair[0] as String, pair[1] as String));
    });
  }();

  static final Map<String, String> printable = (() {
    final String printableKeys = File(path.join(dataRoot, 'printable.json',)).readAsStringSync();
    return (json.decode(printableKeys) as Map<String, dynamic>)
      .cast<String, String>();
  })();

  static final Map<String, List<String>> synonyms = (() {
    final String synonymKeys = File(path.join(dataRoot, 'synonyms.json',)).readAsStringSync();
    final Map<String, dynamic> dynamicSynonym = json.decode(synonymKeys) as Map<String, dynamic>;
    return dynamicSynonym.map((String name, dynamic values) {
      // The keygen and algorithm of macOS relies on synonyms being pairs.
      // See siblingKeyMap in macos_code_gen.dart.
      final List<String> names = (values as List<dynamic>).whereType<String>().toList();
      assert(names.length == 2);
      return MapEntry<String, List<String>>(name, names);
    });
  })();

  static int _sourceToPlane(String source, bool isPrintable) {
    if (isPrintable) {
      return kUnicodePlane.value;
    }
    switch (source) {
      case 'DOM':
        return kUnprintablePlane.value;
      case 'FLUTTER':
        return kFlutterPlane.value;
      default:
        assert(false, 'Unrecognized logical key source $source');
        return kFlutterPlane.value;
    }
  }
}


class LogicalKeyEntry {
  LogicalKeyEntry({
    required this.value,
    required this.name,
    this.keyLabel,
  })  : webNames = <String>[],
        macOSKeyCodeNames = <String>[],
        macOSKeyCodeValues = <int>[],
        iOSKeyCodeNames = <String>[],
        iOSKeyCodeValues = <int>[],
        gtkNames = <String>[],
        gtkValues = <int>[],
        windowsNames = <String>[],
        windowsValues = <int>[],
        androidNames = <String>[],
        androidValues = <int>[],
        fuchsiaValues = <int>[],
        glfwNames = <String>[],
        glfwValues = <int>[];

  LogicalKeyEntry.fromName({
    required int value,
    required String name,
    String? keyLabel,
  })  : this(
          value: value,
          name: name,
          keyLabel: keyLabel,
        );

  LogicalKeyEntry.fromJsonMapEntry(Map<String, dynamic> map)
    : value = map['value'] as int,
      name = map['name'] as String,
      webNames = _getGrandchildList<String>(map, 'names', 'web'),
      macOSKeyCodeNames = _getGrandchildList<String>(map, 'names', 'macos'),
      macOSKeyCodeValues = _getGrandchildList<int>(map, 'values', 'macos'),
      iOSKeyCodeNames = _getGrandchildList<String>(map, 'names', 'ios'),
      iOSKeyCodeValues = _getGrandchildList<int>(map, 'values', 'ios'),
      gtkNames = _getGrandchildList<String>(map, 'names', 'gtk'),
      gtkValues = _getGrandchildList<int>(map, 'values', 'gtk'),
      windowsNames = _getGrandchildList<String>(map, 'names', 'windows'),
      windowsValues = _getGrandchildList<int>(map, 'values', 'windows'),
      androidNames = _getGrandchildList<String>(map, 'names', 'android'),
      androidValues = _getGrandchildList<int>(map, 'values', 'android'),
      fuchsiaValues = _getGrandchildList<int>(map, 'values', 'fuchsia'),
      glfwNames = _getGrandchildList<String>(map, 'names', 'glfw'),
      glfwValues = _getGrandchildList<int>(map, 'values', 'glfw'),
      keyLabel = map['keyLabel'] as String?;

  final int value;

  final String name;

  String get commentName => computeCommentName(name);

  String get constantName => computeConstantName(commentName);

  final List<String> webNames;

  final List<String> macOSKeyCodeNames;

  final List<int> macOSKeyCodeValues;

  final List<String> iOSKeyCodeNames;

  final List<int> iOSKeyCodeValues;

  final List<String> gtkNames;

  final List<int> gtkValues;

  final List<String> windowsNames;

  final List<int> windowsValues;

  final List<String> androidNames;

  final List<int> androidValues;

  final List<int> fuchsiaValues;

  final List<String> glfwNames;

  final List<int> glfwValues;

  final String? keyLabel;

  Map<String, dynamic> toJson() {
    return removeEmptyValues(<String, dynamic>{
      'name': name,
      'value': value,
      'keyLabel': keyLabel,
      'names': <String, dynamic>{
        'web': webNames,
        'macos': macOSKeyCodeNames,
        'ios': iOSKeyCodeNames,
        'gtk': gtkNames,
        'windows': windowsNames,
        'android': androidNames,
        'glfw': glfwNames,
      },
      'values': <String, List<int>>{
        'macos': macOSKeyCodeValues,
        'ios': iOSKeyCodeValues,
        'gtk': gtkValues,
        'windows': windowsValues,
        'android': androidValues,
        'fuchsia': fuchsiaValues,
        'glfw': glfwValues,
      },
    });
  }

  @override
  String toString() {
    return "'$name': (value: ${toHex(value)}) ";
  }

  static String computeName(String rawName) {
    final String result = rawName.replaceAll('PinP', 'PInP');
    if (kDartReservedWords.contains(result)) {
      return '${result}Key';
    }
    return result;
  }

  static String computeCommentName(String name) {
    final String replaced = name.replaceAllMapped(
      RegExp(r'(Digit|Numpad|Lang|Button|Left|Right)([0-9]+)'), (Match match) => '${match.group(1)} ${match.group(2)}',
    );
    return replaced
      // 'fooBar' => 'foo Bar', 'fooBAR' => 'foo BAR'
      .replaceAllMapped(RegExp(r'([^A-Z])([A-Z])'), (Match match) => '${match.group(1)} ${match.group(2)}')
      // 'ABCDoo' => 'ABC Doo'
      .replaceAllMapped(RegExp(r'([A-Z])([A-Z])([a-z])'), (Match match) => '${match.group(1)} ${match.group(2)}${match.group(3)}')
      // 'AB1' => 'AB 1', 'F1' => 'F1'
      .replaceAllMapped(RegExp(r'([A-Z]{2,})([0-9])'), (Match match) => '${match.group(1)} ${match.group(2)}')
      // 'Foo1' => 'Foo 1'
      .replaceAllMapped(RegExp(r'([a-z])([0-9])'), (Match match) => '${match.group(1)} ${match.group(2)}')
      .trim();
  }

  static String computeConstantName(String commentName) {
    // Convert the first word in the comment name.
    final String lowerCamelSpace = commentName.replaceFirstMapped(RegExp(r'^[^ ]+'),
      (Match match) => match[0]!.toLowerCase(),
    );
    final String result = lowerCamelSpace.replaceAll(' ', '');
    if (kDartReservedWords.contains(result)) {
      return '${result}Key';
    }
    return result;
  }

  static int compareByValue(LogicalKeyEntry a, LogicalKeyEntry b) =>
      a.value.compareTo(b.value);
}