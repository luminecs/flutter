// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/common.dart';
import '../base/deferred_component.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/platform.dart';
import '../base/terminal.dart';

abstract class DeferredComponentsValidator {
  DeferredComponentsValidator(this.projectDir, this.logger, this.platform, {
    this.exitOnFail = true,
    String? title,
  }) : outputDir = projectDir
        .childDirectory('build')
        .childDirectory(kDeferredComponentsTempDirectory),
      inputs = <File>[],
      outputs = <File>[],
      title = title ?? 'Deferred components setup verification',
      generatedFiles = <String>[],
      modifiedFiles = <String>[],
      invalidFiles = <String, String>{},
      diffLines = <String>[];

  final Logger logger;

  final Platform platform;

  final bool exitOnFail;

  static const String kLoadingUnitsCacheFileName = 'deferred_components_loading_units.yaml';
  static const String kDeferredComponentsTempDirectory = 'android_deferred_components_setup_files';

  final String title;

  final Directory projectDir;

  final Directory outputDir;

  final List<String> generatedFiles;

  final List<String> modifiedFiles;

  final Map<String, String> invalidFiles;

  // TODO(garyq): implement the diff task.
  final List<String> diffLines;

  Map<String, dynamic>? loadingUnitComparisonResults;

  final List<File> inputs;
  final List<File> outputs;

  bool get changesNeeded => generatedFiles.isNotEmpty
    || modifiedFiles.isNotEmpty
    || invalidFiles.isNotEmpty
    || (loadingUnitComparisonResults != null && !(loadingUnitComparisonResults!['match'] as bool));

  void handleResults() {
    displayResults();
    attemptToolExit();
  }

  static const String _thickDivider = '=================================================================================';
  static const String _thinDivider = '---------------------------------------------------------------------------------';

  void displayResults() {
    if (changesNeeded) {
      logger.printStatus(_thickDivider);
      logger.printStatus(title, indent: (_thickDivider.length - title.length) ~/ 2, emphasis: true);
      logger.printStatus(_thickDivider);
      // Log any file reading/existence errors.
      if (invalidFiles.isNotEmpty) {
        logger.printStatus('Errors checking the following files:\n', emphasis: true);
        for (final String key in invalidFiles.keys) {
          logger.printStatus('  - $key: ${invalidFiles[key]}\n');
        }
      }
      // Log diff file contents, with color highlighting
      if (diffLines.isNotEmpty) {
        logger.printStatus('Diff between `android` and expected files:', emphasis: true);
        logger.printStatus('');
        for (final String line in diffLines) {
          // We only care about diffs in files that have
          // counterparts.
          if (line.startsWith('Only in android')) {
            continue;
          }
          TerminalColor color = TerminalColor.grey;
          if (line.startsWith('+')) {
            color = TerminalColor.green;
          } else if (line.startsWith('-')) {
            color = TerminalColor.red;
          }
          logger.printStatus(line, color: color);
        }
        logger.printStatus('');
      }
      // Log any newly generated and modified files.
      if (generatedFiles.isNotEmpty) {
        logger.printStatus('Newly generated android files:', emphasis: true);
        for (final String filePath in generatedFiles) {
          final String shortenedPath = filePath.substring(projectDir.parent.path.length + 1);
          logger.printStatus('  - $shortenedPath', color: TerminalColor.grey);
        }
        logger.printStatus('');
      }
      if (modifiedFiles.isNotEmpty) {
        logger.printStatus('Modified android files:', emphasis: true);
        for (final String filePath in modifiedFiles) {
          final String shortenedPath = filePath.substring(projectDir.parent.path.length + 1);
          logger.printStatus('  - $shortenedPath', color: TerminalColor.grey);
        }
        logger.printStatus('');
      }
      if (generatedFiles.isNotEmpty || modifiedFiles.isNotEmpty) {
        logger.printStatus('''
The above files have been placed into `build/$kDeferredComponentsTempDirectory`,
a temporary directory. The files should be reviewed and moved into the project's
`android` directory.''');
        if (diffLines.isNotEmpty && !platform.isWindows) {
          logger.printStatus(r'''

The recommended changes can be quickly applied by running:

  $ patch -p0 < build/setup_deferred_components.diff
''');
        }
        logger.printStatus('$_thinDivider\n');
      }
      // Log loading unit golden changes, if any.
      if (loadingUnitComparisonResults != null) {
        if ((loadingUnitComparisonResults!['new'] as List<LoadingUnit>).isNotEmpty) {
          logger.printStatus('New loading units were found:', emphasis: true);
          for (final LoadingUnit unit in loadingUnitComparisonResults!['new'] as List<LoadingUnit>) {
            logger.printStatus(unit.toString(), color: TerminalColor.grey, indent: 2);
          }
          logger.printStatus('');
        }
        if ((loadingUnitComparisonResults!['missing'] as Set<LoadingUnit>).isNotEmpty) {
          logger.printStatus('Previously existing loading units no longer exist:', emphasis: true);
          for (final LoadingUnit unit in loadingUnitComparisonResults!['missing'] as Set<LoadingUnit>) {
            logger.printStatus(unit.toString(), color: TerminalColor.grey, indent: 2);
          }
          logger.printStatus('');
        }
        if (loadingUnitComparisonResults!['match'] as bool) {
          logger.printStatus('No change in generated loading units.\n');
        } else {
          logger.printStatus('''
It is recommended to verify that the changed loading units are expected
and to update the `deferred-components` section in `pubspec.yaml` to
incorporate any changes. The full list of generated loading units can be
referenced in the $kLoadingUnitsCacheFileName file located alongside
pubspec.yaml.

This loading unit check will not fail again on the next build attempt
if no additional changes to the loading units are detected.
$_thinDivider\n''');
        }
      }
      // TODO(garyq): Add link to web tutorial/guide once it is written.
      logger.printStatus('''
Setup verification can be skipped by passing the `--no-validate-deferred-components`
flag, however, doing so may put your app at risk of not functioning even if the
build is successful.
$_thickDivider''');
      return;
    }
    logger.printStatus('$title passed.');
  }

  void attemptToolExit() {
    if (exitOnFail && changesNeeded) {
      throwToolExit('Setup for deferred components incomplete. See recommended actions.', exitCode: 1);
    }
  }
}