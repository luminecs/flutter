import 'package:process/process.dart';
import 'package:xml/xml.dart';

import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/process.dart';
import '../convert.dart';

class PlistParser {
  PlistParser({
    required FileSystem fileSystem,
    required Logger logger,
    required ProcessManager processManager,
  }) : _fileSystem = fileSystem,
       _logger = logger,
       _processUtils = ProcessUtils(logger: logger, processManager: processManager);

  final FileSystem _fileSystem;
  final Logger _logger;
  final ProcessUtils _processUtils;

  // info.pList keys
  static const String kCFBundleIdentifierKey = 'CFBundleIdentifier';
  static const String kCFBundleShortVersionStringKey = 'CFBundleShortVersionString';
  static const String kCFBundleExecutableKey = 'CFBundleExecutable';
  static const String kCFBundleVersionKey = 'CFBundleVersion';
  static const String kCFBundleDisplayNameKey = 'CFBundleDisplayName';
  static const String kCFBundleNameKey = 'CFBundleName';
  static const String kFLTEnableImpellerKey = 'FLTEnableImpeller';
  static const String kMinimumOSVersionKey = 'MinimumOSVersion';
  static const String kNSPrincipalClassKey = 'NSPrincipalClass';

  // entitlement file keys
  static const String kAssociatedDomainsKey = 'com.apple.developer.associated-domains';

  static const String _plutilExecutable = '/usr/bin/plutil';

  String? plistXmlContent(String plistFilePath) {
    if (!_fileSystem.isFileSync(_plutilExecutable)) {
      throw const FileNotFoundException(_plutilExecutable);
    }
    final List<String> args = <String>[
      _plutilExecutable, '-convert', 'xml1', '-o', '-', plistFilePath,
    ];
    try {
      final String xmlContent = _processUtils.runSync(
        args,
        throwOnError: true,
      ).stdout.trim();
      return xmlContent;
    } on ProcessException catch (error) {
      _logger.printError('$error');
      return null;
    }
  }

  bool replaceKey(String plistFilePath, {required String key, String? value }) {
    if (!_fileSystem.isFileSync(_plutilExecutable)) {
      throw const FileNotFoundException(_plutilExecutable);
    }
    final List<String> args;
    if (value == null) {
      args = <String>[
        _plutilExecutable, '-remove', key, plistFilePath,
      ];
    } else {
      args = <String>[
        _plutilExecutable, '-replace', key, '-string', value, plistFilePath,
      ];
    }
    try {
      _processUtils.runSync(
        args,
        throwOnError: true,
      );
    } on ProcessException catch (error) {
      _logger.printError('$error');
      return false;
    }
    return true;
  }

  Map<String, Object> parseFile(String plistFilePath) {
    if (!_fileSystem.isFileSync(plistFilePath)) {
      return const <String, Object>{};
    }

    final String normalizedPlistPath = _fileSystem.path.absolute(plistFilePath);

    final String? xmlContent = plistXmlContent(normalizedPlistPath);
    if (xmlContent == null) {
      return const <String, Object>{};
    }

    return _parseXml(xmlContent);
  }

  Map<String, Object> _parseXml(String xmlContent) {
    final XmlDocument document = XmlDocument.parse(xmlContent);
    // First element child is <plist>. The first element child of plist is <dict>.
    final XmlElement dictObject = document.firstElementChild!.firstElementChild!;
    return _parseXmlDict(dictObject);
  }

  Map<String, Object> _parseXmlDict(XmlElement node) {
    String? lastKey;
    final Map<String, Object> result = <String, Object>{};
    for (final XmlNode child in node.children) {
      if (child is XmlElement) {
        if (child.name.local == 'key') {
          lastKey = child.innerText;
        } else {
          assert(lastKey != null);
          result[lastKey!] = _parseXmlNode(child)!;
          lastKey = null;
        }
      }
    }

    return result;
  }

  static final RegExp _nonBase64Pattern = RegExp('[^a-zA-Z0-9+/=]+');

  Object? _parseXmlNode(XmlElement node) {
    switch (node.name.local){
      case 'string':
        return node.innerText;
      case 'real':
        return double.parse(node.innerText);
      case 'integer':
        return int.parse(node.innerText);
      case 'true':
        return true;
      case 'false':
        return false;
      case 'date':
        return DateTime.parse(node.innerText);
      case 'data':
        return base64.decode(node.innerText.replaceAll(_nonBase64Pattern, ''));
      case 'array':
        return node.children.whereType<XmlElement>().map<Object?>(_parseXmlNode).whereType<Object>().toList();
      case 'dict':
        return _parseXmlDict(node);
    }
    return null;
  }

  T? getValueFromFile<T>(String plistFilePath, String key) {
    final Map<String, dynamic> parsed = parseFile(plistFilePath);
    return parsed[key] as T?;
  }
}