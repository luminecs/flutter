import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../runner/flutter_command.dart';
import 'gen_l10n_types.dart';
import 'language_subtag_registry.dart';

typedef HeaderGenerator = String Function(String regenerateInstructions);
typedef ConstructorGenerator = String Function(LocaleInfo locale);

int sortFilesByPath(File a, File b) {
  return a.path.compareTo(b.path);
}

@immutable
class LocaleInfo implements Comparable<LocaleInfo> {
  const LocaleInfo({
    required this.languageCode,
    required this.scriptCode,
    required this.countryCode,
    required this.length,
    required this.originalString,
  });

  factory LocaleInfo.fromString(String locale,
      {bool deriveScriptCode = false}) {
    final List<String> codes = locale.split('_'); // [language, script, country]
    assert(codes.isNotEmpty && codes.length < 4);
    final String languageCode = codes[0];
    String? scriptCode;
    String? countryCode;
    int length = codes.length;
    String originalString = locale;
    if (codes.length == 2) {
      scriptCode = codes[1].length >= 4 ? codes[1] : null;
      countryCode = codes[1].length < 4 ? codes[1] : null;
    } else if (codes.length == 3) {
      scriptCode = codes[1].length > codes[2].length ? codes[1] : codes[2];
      countryCode = codes[1].length < codes[2].length ? codes[1] : codes[2];
    }
    assert(codes[0].isNotEmpty);
    assert(countryCode == null || countryCode.isNotEmpty);
    assert(scriptCode == null || scriptCode.isNotEmpty);

    if (deriveScriptCode && scriptCode == null) {
      switch (languageCode) {
        case 'zh':
          {
            if (countryCode == null) {
              scriptCode = 'Hans';
            }
            switch (countryCode) {
              case 'CN':
              case 'SG':
                scriptCode = 'Hans';
              case 'TW':
              case 'HK':
              case 'MO':
                scriptCode = 'Hant';
            }
            break;
          }
        case 'sr':
          {
            if (countryCode == null) {
              scriptCode = 'Cyrl';
            }
            break;
          }
      }
      // Increment length if we were able to assume a scriptCode.
      if (scriptCode != null) {
        length += 1;
      }
      // Update the base string to reflect assumed scriptCodes.
      originalString = languageCode;
      if (scriptCode != null) {
        originalString += '_$scriptCode';
      }
      if (countryCode != null) {
        originalString += '_$countryCode';
      }
    }

    return LocaleInfo(
      languageCode: languageCode,
      scriptCode: scriptCode,
      countryCode: countryCode,
      length: length,
      originalString: originalString,
    );
  }

  final String languageCode;
  final String? scriptCode;
  final String? countryCode;
  final int length; // The number of fields. Ranges from 1-3.
  final String originalString; // Original un-parsed locale string.

  String camelCase() {
    return originalString
        .split('_')
        .map<String>((String part) =>
            part.substring(0, 1).toUpperCase() +
            part.substring(1).toLowerCase())
        .join();
  }

  @override
  bool operator ==(Object other) {
    return other is LocaleInfo && other.originalString == originalString;
  }

  @override
  int get hashCode => originalString.hashCode;

  @override
  String toString() {
    return originalString;
  }

  @override
  int compareTo(LocaleInfo other) {
    return originalString.compareTo(other.originalString);
  }
}

// See also //master/tools/gen_locale.dart in the engine repo.
Map<String, List<String>> _parseSection(String section) {
  final Map<String, List<String>> result = <String, List<String>>{};
  late List<String> lastHeading;
  for (final String line in section.split('\n')) {
    if (line == '') {
      continue;
    }
    if (line.startsWith('  ')) {
      lastHeading[lastHeading.length - 1] =
          '${lastHeading.last}${line.substring(1)}';
      continue;
    }
    final int colon = line.indexOf(':');
    if (colon <= 0) {
      throw Exception('not sure how to deal with "$line"');
    }
    final String name = line.substring(0, colon);
    final String value = line.substring(colon + 2);
    lastHeading = result.putIfAbsent(name, () => <String>[]);
    result[name]!.add(value);
  }
  return result;
}

final Map<String, String> _languages = <String, String>{};
final Map<String, String> _regions = <String, String>{};
final Map<String, String> _scripts = <String, String>{};
const String kProvincePrefix = ', Province of ';
const String kParentheticalPrefix = ' (';

void precacheLanguageAndRegionTags() {
  final List<Map<String, List<String>>> sections = languageSubtagRegistry
      .split('%%')
      .skip(1)
      .map<Map<String, List<String>>>(_parseSection)
      .toList();
  for (final Map<String, List<String>> section in sections) {
    assert(section.containsKey('Type'), section.toString());
    final String type = section['Type']!.single;
    if (type == 'language' || type == 'region' || type == 'script') {
      assert(
          section.containsKey('Subtag') && section.containsKey('Description'),
          section.toString());
      final String subtag = section['Subtag']!.single;
      String description = section['Description']!.join(' ');
      if (description.startsWith('United ')) {
        description = 'the $description';
      }
      if (description.contains(kParentheticalPrefix)) {
        description =
            description.substring(0, description.indexOf(kParentheticalPrefix));
      }
      if (description.contains(kProvincePrefix)) {
        description =
            description.substring(0, description.indexOf(kProvincePrefix));
      }
      if (description.endsWith(' Republic')) {
        description = 'the $description';
      }
      switch (type) {
        case 'language':
          _languages[subtag] = description;
        case 'region':
          _regions[subtag] = description;
        case 'script':
          _scripts[subtag] = description;
      }
    }
  }
}

String describeLocale(String tag) {
  final List<String> subtags = tag.split('_');
  assert(subtags.isNotEmpty);
  final String languageCode = subtags[0];
  if (!_languages.containsKey(languageCode)) {
    throw L10nException(
      '"$languageCode" is not a supported language code.\n'
      'See https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry '
      'for the supported list.',
    );
  }
  final String language = _languages[languageCode]!;
  String output = language;
  String? region;
  String? script;
  if (subtags.length == 2) {
    region = _regions[subtags[1]];
    script = _scripts[subtags[1]];
    assert(region != null || script != null);
  } else if (subtags.length >= 3) {
    region = _regions[subtags[2]];
    script = _scripts[subtags[1]];
    assert(region != null && script != null);
  }
  if (region != null) {
    output += ', as used in $region';
  }
  if (script != null) {
    output += ', using the $script script';
  }
  return output;
}

String generateString(String value) {
  const String backslash = '__BACKSLASH__';
  assert(
      !value.contains(backslash),
      'Input string cannot contain the sequence: '
      '"__BACKSLASH__", as it is used as part of '
      'backslash character processing.');

  value = value
      // Replace backslashes with a placeholder for now to properly parse
      // other special characters.
      .replaceAll(r'\', backslash)
      .replaceAll(r'$', r'\$')
      .replaceAll("'", r"\'")
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\f', r'\f')
      .replaceAll('\t', r'\t')
      .replaceAll('\r', r'\r')
      .replaceAll('\b', r'\b')
      // Reintroduce escaped backslashes into generated Dart string.
      .replaceAll(backslash, r'\\');

  return value;
}

String generateReturnExpr(List<String> expressions,
    {bool isSingleStringVar = false}) {
  if (expressions.isEmpty) {
    return "''";
  } else if (isSingleStringVar) {
    // If our expression is "$varName" where varName is a String, this is equivalent to just varName.
    return expressions[0].substring(1);
  } else {
    final String string = expressions.reversed.fold<String>('',
        (String string, String expression) {
      if (expression[0] != r'$') {
        return expression + string;
      }
      final RegExp alphanumeric = RegExp(r'^([0-9a-zA-Z]|_)+$');
      if (alphanumeric.hasMatch(expression.substring(1)) &&
          !(string.isNotEmpty && alphanumeric.hasMatch(string[0]))) {
        return '$expression$string';
      } else {
        return '\${${expression.substring(1)}}$string';
      }
    });
    return "'$string'";
  }
}

class LocalizationOptions {
  LocalizationOptions({
    required this.arbDir,
    this.outputDir,
    String? templateArbFile,
    String? outputLocalizationFile,
    this.untranslatedMessagesFile,
    String? outputClass,
    this.preferredSupportedLocales,
    this.header,
    this.headerFile,
    bool? useDeferredLoading,
    this.genInputsAndOutputsList,
    bool? syntheticPackage,
    this.projectDir,
    bool? requiredResourceAttributes,
    bool? nullableGetter,
    bool? format,
    bool? useEscaping,
    bool? suppressWarnings,
    bool? relaxSyntax,
  })  : templateArbFile = templateArbFile ?? 'app_en.arb',
        outputLocalizationFile =
            outputLocalizationFile ?? 'app_localizations.dart',
        outputClass = outputClass ?? 'AppLocalizations',
        useDeferredLoading = useDeferredLoading ?? false,
        syntheticPackage = syntheticPackage ?? true,
        requiredResourceAttributes = requiredResourceAttributes ?? false,
        nullableGetter = nullableGetter ?? true,
        format = format ?? false,
        useEscaping = useEscaping ?? false,
        suppressWarnings = suppressWarnings ?? false,
        relaxSyntax = relaxSyntax ?? false;

  final String arbDir;

  final String? outputDir;

  final String templateArbFile;

  final String outputLocalizationFile;

  final String? untranslatedMessagesFile;

  final String outputClass;

  final List<String>? preferredSupportedLocales;

  final String? header;

  final String? headerFile;

  final bool useDeferredLoading;

  final String? genInputsAndOutputsList;

  final bool syntheticPackage;

  final String? projectDir;

  final bool requiredResourceAttributes;

  final bool nullableGetter;

  final bool format;

  final bool useEscaping;

  final bool suppressWarnings;

  final bool relaxSyntax;
}

LocalizationOptions parseLocalizationsOptionsFromYAML({
  required File file,
  required Logger logger,
  required String defaultArbDir,
}) {
  final String contents = file.readAsStringSync();
  if (contents.trim().isEmpty) {
    return LocalizationOptions(arbDir: defaultArbDir);
  }
  final YamlNode yamlNode;
  try {
    yamlNode = loadYamlNode(file.readAsStringSync());
  } on YamlException catch (err) {
    throwToolExit(err.message);
  }
  if (yamlNode is! YamlMap) {
    logger.printError(
        'Expected ${file.path} to contain a map, instead was $yamlNode');
    throw Exception();
  }
  return LocalizationOptions(
    arbDir: _tryReadUri(yamlNode, 'arb-dir', logger)?.path ?? defaultArbDir,
    outputDir: _tryReadUri(yamlNode, 'output-dir', logger)?.path,
    templateArbFile: _tryReadUri(yamlNode, 'template-arb-file', logger)?.path,
    outputLocalizationFile:
        _tryReadUri(yamlNode, 'output-localization-file', logger)?.path,
    untranslatedMessagesFile:
        _tryReadUri(yamlNode, 'untranslated-messages-file', logger)?.path,
    outputClass: _tryReadString(yamlNode, 'output-class', logger),
    header: _tryReadString(yamlNode, 'header', logger),
    headerFile: _tryReadUri(yamlNode, 'header-file', logger)?.path,
    useDeferredLoading: _tryReadBool(yamlNode, 'use-deferred-loading', logger),
    preferredSupportedLocales:
        _tryReadStringList(yamlNode, 'preferred-supported-locales', logger),
    syntheticPackage: _tryReadBool(yamlNode, 'synthetic-package', logger),
    requiredResourceAttributes:
        _tryReadBool(yamlNode, 'required-resource-attributes', logger),
    nullableGetter: _tryReadBool(yamlNode, 'nullable-getter', logger),
    format: _tryReadBool(yamlNode, 'format', logger),
    useEscaping: _tryReadBool(yamlNode, 'use-escaping', logger),
    suppressWarnings: _tryReadBool(yamlNode, 'suppress-warnings', logger),
    relaxSyntax: _tryReadBool(yamlNode, 'relax-syntax', logger),
  );
}

LocalizationOptions parseLocalizationsOptionsFromCommand({
  required FlutterCommand command,
  required String defaultArbDir,
}) {
  return LocalizationOptions(
    arbDir: command.stringArg('arb-dir') ?? defaultArbDir,
    outputDir: command.stringArg('output-dir'),
    outputLocalizationFile: command.stringArg('output-localization-file'),
    templateArbFile: command.stringArg('template-arb-file'),
    untranslatedMessagesFile: command.stringArg('untranslated-messages-file'),
    outputClass: command.stringArg('output-class'),
    header: command.stringArg('header'),
    headerFile: command.stringArg('header-file'),
    useDeferredLoading: command.boolArg('use-deferred-loading'),
    genInputsAndOutputsList: command.stringArg('gen-inputs-and-outputs-list'),
    syntheticPackage: command.boolArg('synthetic-package'),
    projectDir: command.stringArg('project-dir'),
    requiredResourceAttributes: command.boolArg('required-resource-attributes'),
    nullableGetter: command.boolArg('nullable-getter'),
    format: command.boolArg('format'),
    useEscaping: command.boolArg('use-escaping'),
    suppressWarnings: command.boolArg('suppress-warnings'),
  );
}

// Try to read a `bool` value or null from `yamlMap`, otherwise throw.
bool? _tryReadBool(YamlMap yamlMap, String key, Logger logger) {
  final Object? value = yamlMap[key];
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    logger.printError(
        'Expected "$key" to have a bool value, instead was "$value"');
    throw Exception();
  }
  return value;
}

// Try to read a `String` value or null from `yamlMap`, otherwise throw.
String? _tryReadString(YamlMap yamlMap, String key, Logger logger) {
  final Object? value = yamlMap[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    logger.printError(
        'Expected "$key" to have a String value, instead was "$value"');
    throw Exception();
  }
  return value;
}

List<String>? _tryReadStringList(YamlMap yamlMap, String key, Logger logger) {
  final Object? value = yamlMap[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return <String>[value];
  }
  if (value is Iterable) {
    return value.map((dynamic e) => e.toString()).toList();
  }
  logger.printError('"$value" must be String or List.');
  throw Exception();
}

// Try to read a valid `Uri` or null from `yamlMap`, otherwise throw.
Uri? _tryReadUri(YamlMap yamlMap, String key, Logger logger) {
  final String? value = _tryReadString(yamlMap, key, logger);
  if (value == null) {
    return null;
  }
  final Uri? uri = Uri.tryParse(value);
  if (uri == null) {
    logger.printError('"$value" must be a relative file URI');
  }
  return uri;
}
