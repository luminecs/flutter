
import 'dart:convert';

import 'utils.dart';

class PhysicalKeyData {
  factory PhysicalKeyData(
    String chromiumHidCodes,
    String androidKeyboardLayout,
    String androidNameMap,
  ) {
    final Map<String, List<int>> nameToAndroidScanCodes = _readAndroidScanCodes(androidKeyboardLayout, androidNameMap);
    final Map<String, PhysicalKeyEntry> data = _readHidEntries(
      chromiumHidCodes,
      nameToAndroidScanCodes,
    );
    final List<MapEntry<String, PhysicalKeyEntry>> sortedEntries = data.entries.toList()..sort(
      (MapEntry<String, PhysicalKeyEntry> a, MapEntry<String, PhysicalKeyEntry> b) =>
        PhysicalKeyEntry.compareByUsbHidCode(a.value, b.value),
    );
    data
      ..clear()
      ..addEntries(sortedEntries);
    return PhysicalKeyData._(data);
  }

  factory PhysicalKeyData.fromJson(Map<String, dynamic> contentMap) {
    final Map<String, PhysicalKeyEntry> data = <String, PhysicalKeyEntry>{};
    for (final MapEntry<String, dynamic> jsonEntry in contentMap.entries) {
      final PhysicalKeyEntry entry = PhysicalKeyEntry.fromJsonMapEntry(jsonEntry.value as Map<String, dynamic>);
      data[entry.name] = entry;
    }
    return PhysicalKeyData._(data);
  }

  PhysicalKeyData._(this._data);

  PhysicalKeyEntry? tryEntryByName(String name) {
    return _data[name];
  }

  PhysicalKeyEntry entryByName(String name) {
    final PhysicalKeyEntry? entry = tryEntryByName(name);
    assert(entry != null,
        'Unable to find logical entry by name $name.');
    return entry!;
  }

  Iterable<PhysicalKeyEntry> get entries => _data.values;

  // Keys mapped from their names.
  final Map<String, PhysicalKeyEntry> _data;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> outputMap = <String, dynamic>{};
    for (final PhysicalKeyEntry entry in _data.values) {
      outputMap[entry.name] = entry.toJson();
    }
    return outputMap;
  }

  static Map<String, List<int>> _readAndroidScanCodes(String keyboardLayout, String nameMap) {
    final RegExp keyEntry = RegExp(
      r'#?\s*' // Optional comment mark
      r'key\s+' // Literal "key"
      r'(?<id>[0-9]+)\s*' // ID section
      r'"?(?:KEY_)?(?<name>[0-9A-Z_]+|\(undefined\))"?\s*' // Name section
      r'(?<function>FUNCTION)?' // Optional literal "FUNCTION"
    );
    final Map<String, List<int>> androidNameToScanCodes = <String, List<int>>{};
    for (final RegExpMatch match in keyEntry.allMatches(keyboardLayout)) {
      if (match.namedGroup('function') == 'FUNCTION') {
        // Skip odd duplicate Android FUNCTION keys (F1-F12 are already defined).
        continue;
      }
      final String name = match.namedGroup('name')!;
      if (name == '(undefined)') {
        // Skip undefined scan codes.
        continue;
      }
      androidNameToScanCodes.putIfAbsent(name, () => <int>[])
        .add(int.parse(match.namedGroup('id')!));
    }

    // Cast Android dom map
    final Map<String, List<String>> nameToAndroidNames = (json.decode(nameMap) as Map<String, dynamic>)
      .cast<String, List<dynamic>>()
      .map<String, List<String>>((String key, List<dynamic> value) {
        return MapEntry<String, List<String>>(key, value.cast<String>());
      });

    final Map<String, List<int>> result = nameToAndroidNames.map((String name, List<String> androidNames) {
      final Set<int> scanCodes = <int>{};
      for (final String androidName in androidNames) {
        scanCodes.addAll(androidNameToScanCodes[androidName] ?? <int>[]);
      }
      return MapEntry<String, List<int>>(name, scanCodes.toList()..sort());
    });

    return result;
  }

  static Map<String, PhysicalKeyEntry> _readHidEntries(
    String input,
    Map<String, List<int>> nameToAndroidScanCodes,
  ) {
    final Map<int, PhysicalKeyEntry> entries = <int, PhysicalKeyEntry>{};
    final RegExp usbMapRegExp = RegExp(
      r'DOM_CODE\s*\(\s*'
      r'0[xX](?<usb>[a-fA-F0-9]+),\s*'
      r'0[xX](?<evdev>[a-fA-F0-9]+),\s*'
      r'0[xX](?<xkb>[a-fA-F0-9]+),\s*'
      r'0[xX](?<win>[a-fA-F0-9]+),\s*'
      r'0[xX](?<mac>[a-fA-F0-9]+),\s*'
      r'(?:"(?<code>[^\s]+)")?[^")]*?,'
      r'\s*(?<enum>[^\s]+?)\s*'
      r'\)',
      // Multiline is necessary because some definitions spread across
      // multiple lines.
      multiLine: true,
    );
    final RegExp commentRegExp = RegExp(r'//.*$', multiLine: true);
    input = input.replaceAll(commentRegExp, '');
    for (final RegExpMatch match in usbMapRegExp.allMatches(input)) {
      final int usbHidCode = getHex(match.namedGroup('usb')!);
      final int evdevCode = getHex(match.namedGroup('evdev')!);
      final int xKbScanCode = getHex(match.namedGroup('xkb')!);
      final int windowsScanCode = getHex(match.namedGroup('win')!);
      final int macScanCode = getHex(match.namedGroup('mac')!);
      final String? chromiumCode = match.namedGroup('code');
      // The input data has a typo...
      final String enumName = match.namedGroup('enum')!.replaceAll('MINIMIUM', 'MINIMUM');

      final String name = chromiumCode ?? shoutingToUpperCamel(enumName);
      if (name == 'IntlHash' || name == 'None') {
        // Skip key that is not actually generated by any keyboard.
        continue;
      }
      final PhysicalKeyEntry? existing = entries[usbHidCode];
      // Allow duplicate entries for Fn, which overwrites.
      if (existing != null && existing.name != 'Fn') {
        // If it's an existing entry, the only thing we currently support is
        // to insert an extra DOMKey. The other entries must be empty.
        assert(evdevCode == 0
            && xKbScanCode == 0
            && windowsScanCode == 0
            && macScanCode == 0xffff
            && chromiumCode != null
            && chromiumCode.isNotEmpty,
            'Duplicate usbHidCode ${existing.usbHidCode} of key ${existing.name} '
            'conflicts with existing ${entries[existing.usbHidCode]!.name}.');
        existing.otherWebCodes.add(chromiumCode!);
        continue;
      }
      final PhysicalKeyEntry newEntry = PhysicalKeyEntry(
        usbHidCode: usbHidCode,
        androidScanCodes: nameToAndroidScanCodes[name] ?? <int>[],
        evdevCode: evdevCode == 0 ? null : evdevCode,
        xKbScanCode: xKbScanCode == 0 ? null : xKbScanCode,
        windowsScanCode: windowsScanCode == 0 ? null : windowsScanCode,
        macOSScanCode: macScanCode == 0xffff ? null : macScanCode,
        iOSScanCode: (usbHidCode & 0x070000) == 0x070000 ? (usbHidCode ^ 0x070000) : null,
        name: name,
        chromiumCode: chromiumCode,
      );
      entries[newEntry.usbHidCode] = newEntry;
    }
    return entries.map((int code, PhysicalKeyEntry entry) =>
        MapEntry<String, PhysicalKeyEntry>(entry.name, entry));
  }
}

class PhysicalKeyEntry {
  PhysicalKeyEntry({
    required this.usbHidCode,
    required this.name,
    required this.androidScanCodes,
    required this.evdevCode,
    required this.xKbScanCode,
    required this.windowsScanCode,
    required this.macOSScanCode,
    required this.iOSScanCode,
    required this.chromiumCode,
    List<String>? otherWebCodes,
  }) : otherWebCodes = otherWebCodes ?? <String>[];

  factory PhysicalKeyEntry.fromJsonMapEntry(Map<String, dynamic> map) {
    final Map<String, dynamic> names = map['names'] as Map<String, dynamic>;
    final Map<String, dynamic> scanCodes = map['scanCodes'] as Map<String, dynamic>;
    return PhysicalKeyEntry(
      name: names['name'] as String,
      chromiumCode: names['chromium'] as String?,
      usbHidCode: scanCodes['usb'] as int,
      androidScanCodes: (scanCodes['android'] as List<dynamic>?)?.cast<int>() ?? <int>[],
      evdevCode: scanCodes['linux'] as int?,
      xKbScanCode: scanCodes['xkb'] as int?,
      windowsScanCode: scanCodes['windows'] as int?,
      macOSScanCode: scanCodes['macos'] as int?,
      iOSScanCode: scanCodes['ios'] as int?,
      otherWebCodes: (map['otherWebCodes'] as List<dynamic>?)?.cast<String>(),
    );
  }

  final int usbHidCode;

  final int? evdevCode;
  final int? xKbScanCode;
  final int? windowsScanCode;
  final int? macOSScanCode;
  final int? iOSScanCode;
  final List<int> androidScanCodes;
  final String name;
  final String? chromiumCode;
  final List<String> otherWebCodes;

  Iterable<String> webCodes() sync* {
    if (chromiumCode != null) {
      yield chromiumCode!;
    }
    yield* otherWebCodes;
  }

  Map<String, dynamic> toJson() {
    return removeEmptyValues(<String, dynamic>{
      'names': <String, dynamic>{
        'name': name,
        'chromium': chromiumCode,
      },
      'otherWebCodes': otherWebCodes,
      'scanCodes': <String, dynamic>{
        'android': androidScanCodes,
        'usb': usbHidCode,
        'linux': evdevCode,
        'xkb': xKbScanCode,
        'windows': windowsScanCode,
        'macos': macOSScanCode,
        'ios': iOSScanCode,
      },
    });
  }

  static String getCommentName(String constantName) {
    String upperCamel = lowerCamelToUpperCamel(constantName);
    upperCamel = upperCamel.replaceAllMapped(
      RegExp(r'(Digit|Numpad|Lang|Button|Left|Right)([0-9]+)'),
      (Match match) => '${match.group(1)} ${match.group(2)}',
    );
    return upperCamel.replaceAllMapped(RegExp(r'([A-Z])'), (Match match) => ' ${match.group(1)}').trim();
  }

  String get commentName => getCommentName(constantName);

  late final String constantName = (() {
    String? result;
    if (name.isEmpty) {
      // If it doesn't have a DomKey name then use the Chromium symbol name.
      result = chromiumCode;
    } else {
      result = upperCamelToLowerCamel(name);
    }
    result ??= 'Key${toHex(usbHidCode)}';
    if (kDartReservedWords.contains(result)) {
      return '${result}Key';
    }
    return result;
  })();

  @override
  String toString() {
    final String otherWebStr = otherWebCodes.isEmpty
        ? ''
        : ', otherWebCodes: [${otherWebCodes.join(', ')}]';
    return """'$constantName': (name: "$name", usbHidCode: ${toHex(usbHidCode)}, """
        'linuxScanCode: ${toHex(evdevCode)}, xKbScanCode: ${toHex(xKbScanCode)}, '
        'windowsKeyCode: ${toHex(windowsScanCode)}, macOSScanCode: ${toHex(macOSScanCode)}, '
        'windowsScanCode: ${toHex(windowsScanCode)}, chromiumSymbolName: $chromiumCode '
        'iOSScanCode: ${toHex(iOSScanCode)})$otherWebStr';
  }

  static int compareByUsbHidCode(PhysicalKeyEntry a, PhysicalKeyEntry b) =>
      a.usbHidCode.compareTo(b.usbHidCode);
}