// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:xml/xml.dart';

import '../base/deferred_component.dart';
import '../base/error_handling_io.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../globals.dart' as globals;
import '../project.dart';
import '../template.dart';
import 'deferred_components_validator.dart';

class DeferredComponentsPrebuildValidator extends DeferredComponentsValidator {
  DeferredComponentsPrebuildValidator(super.projectDir, super.logger, super.platform, {
    super.exitOnFail,
    super.title,
    Directory? templatesDir,
  }) : _templatesDir = templatesDir;

  final Directory? _templatesDir;

  Future<bool> checkAndroidDynamicFeature(List<DeferredComponent> components) async {
    inputs.add(projectDir.childFile('pubspec.yaml'));
    if (components.isEmpty) {
      return false;
    }
    bool changesMade = false;
    for (final DeferredComponent component in components) {
      final _DeferredComponentAndroidFiles androidFiles = _DeferredComponentAndroidFiles(
        name: component.name,
        projectDir: projectDir,
        logger: logger,
        templatesDir: _templatesDir
      );
      if (!androidFiles.verifyFilesExist()) {
        // generate into temp directory
        final Map<String, List<File>> results = await androidFiles.generateFiles(
          alternateAndroidDir: outputDir,
          clearAlternateOutputDir: true,
        );
        if (results.containsKey('outputs')) {
          for (final File file in results['outputs']!) {
            generatedFiles.add(file.path);
            changesMade = true;
          }
          outputs.addAll(results['outputs']!);
        }
        if (results.containsKey('inputs')) {
          inputs.addAll(results['inputs']!);
        }
      }
    }
    return !changesMade;
  }

  bool checkAndroidResourcesStrings(List<DeferredComponent> components) {
    final Directory androidDir = projectDir.childDirectory('android');
    inputs.add(projectDir.childFile('pubspec.yaml'));

    // Add component name mapping to strings.xml
    final File stringRes = androidDir
      .childDirectory('app')
      .childDirectory('src')
      .childDirectory('main')
      .childDirectory('res')
      .childDirectory('values')
      .childFile('strings.xml');
    inputs.add(stringRes);
    final File stringResOutput = outputDir
      .childDirectory('app')
      .childDirectory('src')
      .childDirectory('main')
      .childDirectory('res')
      .childDirectory('values')
      .childFile('strings.xml');
    ErrorHandlingFileSystem.deleteIfExists(stringResOutput);
    if (components.isEmpty) {
      return true;
    }
    final Map<String, String> requiredEntriesMap  = <String, String>{};
    for (final DeferredComponent component in components) {
      requiredEntriesMap['${component.name}Name'] = component.name;
    }
    if (stringRes.existsSync()) {
      bool modified = false;
      XmlDocument document;
      try {
        document = XmlDocument.parse(stringRes.readAsStringSync());
      } on XmlException {
        invalidFiles[stringRes.path] = 'Error parsing $stringRes '
        'Please ensure that the strings.xml is a valid XML document and '
        'try again.';
        return false;
      }
      // Check if all required lines are present, and fix if name exists, but
      // wrong string stored.
      for (final XmlElement resources in document.findAllElements('resources')) {
        for (final XmlElement element in resources.findElements('string')) {
          final String? name = element.getAttribute('name');
          if (requiredEntriesMap.containsKey(name)) {
            if (element.innerText != requiredEntriesMap[name]) {
              element.innerText = requiredEntriesMap[name]!;
              modified = true;
            }
            requiredEntriesMap.remove(name);
          }
        }
        requiredEntriesMap.forEach((String key, String value) {
          modified = true;
          final XmlElement newStringElement = XmlElement(
            XmlName.fromString('string'),
            <XmlAttribute>[
              XmlAttribute(XmlName.fromString('name'), key),
            ],
            <XmlNode>[
              XmlText(value),
            ],
          );
          resources.children.add(newStringElement);
        });
        break;
      }
      if (modified) {
        stringResOutput.createSync(recursive: true);
        stringResOutput.writeAsStringSync(document.toXmlString(pretty: true));
        modifiedFiles.add(stringResOutput.path);
        return false;
      }
      return true;
    }
    // strings.xml does not exist, generate completely new file.
    stringResOutput.createSync(recursive: true);
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('''
<?xml version="1.0" encoding="utf-8"?>
<resources>
''');
    for (final String key in requiredEntriesMap.keys) {
      buffer.write('    <string name="$key">${requiredEntriesMap[key]}</string>\n');
    }
    buffer.write(
'''
</resources>

''');
    stringResOutput.writeAsStringSync(buffer.toString(), flush: true, mode: FileMode.append);
    generatedFiles.add(stringResOutput.path);
    return false;
  }

  void clearOutputDir() {
    final Directory dir = projectDir.childDirectory('build').childDirectory(DeferredComponentsValidator.kDeferredComponentsTempDirectory);
    ErrorHandlingFileSystem.deleteIfExists(dir, recursive: true);
  }
}

// Handles a single deferred component's android dynamic feature module
// directory.
class _DeferredComponentAndroidFiles {
  _DeferredComponentAndroidFiles({
    required this.name,
    required this.projectDir,
    required this.logger,
    Directory? templatesDir,
  }) : _templatesDir = templatesDir;

  // The name of the deferred component.
  final String name;
  final Directory projectDir;
  final Logger logger;
  final Directory? _templatesDir;

  Directory get androidDir => projectDir.childDirectory('android');
  Directory get componentDir => androidDir.childDirectory(name);

  File get androidManifestFile => componentDir.childDirectory('src').childDirectory('main').childFile('AndroidManifest.xml');
  File get buildGradleFile => componentDir.childFile('build.gradle');

  // True when AndroidManifest.xml and build.gradle exist for the android dynamic feature.
  bool verifyFilesExist() {
    return androidManifestFile.existsSync() && buildGradleFile.existsSync();
  }

  // Generates any missing basic files for the dynamic feature into a temporary directory.
  Future<Map<String, List<File>>> generateFiles({Directory? alternateAndroidDir, bool clearAlternateOutputDir = false}) async {
    final Directory outputDir = alternateAndroidDir?.childDirectory(name) ?? componentDir;
    if (clearAlternateOutputDir && alternateAndroidDir != null) {
      ErrorHandlingFileSystem.deleteIfExists(outputDir);
    }
    final List<File> inputs = <File>[];
    inputs.add(androidManifestFile);
    inputs.add(buildGradleFile);
    final Map<String, List<File>> results = <String, List<File>>{'inputs': inputs};
    results['outputs'] = await _setupComponentFiles(outputDir);
    return results;
  }

  // generates default build.gradle and AndroidManifest.xml for the deferred component.
  Future<List<File>> _setupComponentFiles(Directory outputDir) async {
    Template template;
    final Directory? templatesDir = _templatesDir;
    if (templatesDir != null) {
      final Directory templateComponentDir = templatesDir.childDirectory('module${globals.fs.path.separator}android${globals.fs.path.separator}deferred_component');
      template = Template(templateComponentDir, templateComponentDir,
        fileSystem: globals.fs,
        logger: logger,
        templateRenderer: globals.templateRenderer,
      );
    } else {
      template = await Template.fromName('module${globals.fs.path.separator}android${globals.fs.path.separator}deferred_component',
        fileSystem: globals.fs,
        templateManifest: null,
        logger: logger,
        templateRenderer: globals.templateRenderer,
      );
    }
    final Map<String, Object> context = <String, Object>{
      'androidIdentifier': FlutterProject.current().manifest.androidPackage ?? 'com.example.${FlutterProject.current().manifest.appName}',
      'componentName': name,
    };

    template.render(outputDir, context);

    final List<File> generatedFiles = <File>[];

    final File tempBuildGradle = outputDir.childFile('build.gradle');
    if (!buildGradleFile.existsSync()) {
      generatedFiles.add(tempBuildGradle);
    } else {
      ErrorHandlingFileSystem.deleteIfExists(tempBuildGradle);
    }
    final File tempAndroidManifest = outputDir
      .childDirectory('src')
      .childDirectory('main')
      .childFile('AndroidManifest.xml');
    if (!androidManifestFile.existsSync()) {
      generatedFiles.add(tempAndroidManifest);
    } else {
      ErrorHandlingFileSystem.deleteIfExists(tempAndroidManifest);
    }
    return generatedFiles;
  }
}