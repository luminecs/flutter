import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import 'package:path/path.dart' as path;
import 'package:platform/platform.dart' as platform;

import 'package:process/process.dart';

class CommandException implements Exception {}

Future<void> main() async {
  await postProcess();
}

Future<void> postProcess() async {
  final String revision = await gitRevision(fullLength: true);
  print('Docs revision being processed: $revision');
  final Directory tmpFolder = Directory.systemTemp.createTempSync();
  final String zipDestination = path.join(tmpFolder.path, 'api_docs.zip');

  if (!Platform.environment.containsKey('SDK_CHECKOUT_PATH')) {
    print('SDK_CHECKOUT_PATH env variable is required for this script');
    exit(1);
  }
  final String checkoutPath = Platform.environment['SDK_CHECKOUT_PATH']!;
  final String docsPath = path.join(checkoutPath, 'dev', 'docs');
  await runProcessWithValidations(
    <String>[
      'curl',
      '-L',
      'https://storage.googleapis.com/flutter_infra_release/flutter/$revision/api_docs.zip',
      '--output',
      zipDestination,
      '--fail',
    ],
    docsPath,
  );

  // Unzip to docs folder.
  await runProcessWithValidations(
    <String>[
      'unzip',
      '-o',
      zipDestination,
    ],
    docsPath,
  );

  // Generate versions file.
  await runProcessWithValidations(
    <String>['flutter', '--version'],
    docsPath,
  );
  final File versionFile = File('version');
  final String version = versionFile.readAsStringSync();
  // Recreate footer
  final String publishPath =
      path.join(docsPath, '..', 'docs', 'doc', 'flutter', 'footer.js');
  final File footerFile = File(publishPath)..createSync(recursive: true);
  createFooter(footerFile, version);
}

Future<String> gitRevision({
  bool fullLength = false,
  @visibleForTesting
  platform.Platform platform = const platform.LocalPlatform(),
  @visibleForTesting
  ProcessManager processManager = const LocalProcessManager(),
}) async {
  const int kGitRevisionLength = 10;

  final ProcessResult gitResult =
      processManager.runSync(<String>['git', 'rev-parse', 'HEAD']);
  if (gitResult.exitCode != 0) {
    throw 'git rev-parse exit with non-zero exit code: ${gitResult.exitCode}';
  }
  final String gitRevision = (gitResult.stdout as String).trim();
  if (fullLength) {
    return gitRevision;
  }
  return gitRevision.length > kGitRevisionLength
      ? gitRevision.substring(0, kGitRevisionLength)
      : gitRevision;
}

Future<void> runProcessWithValidations(
  List<String> command,
  String workingDirectory, {
  @visibleForTesting
  ProcessManager processManager = const LocalProcessManager(),
  bool verbose = true,
}) async {
  final ProcessResult result = processManager.runSync(command,
      stdoutEncoding: utf8, workingDirectory: workingDirectory);
  if (result.exitCode == 0) {
    if (verbose) {
      print('stdout: ${result.stdout}');
    }
  } else {
    if (verbose) {
      print('stderr: ${result.stderr}');
    }
    throw CommandException();
  }
}

Future<String> getBranchName({
  @visibleForTesting
  platform.Platform platform = const platform.LocalPlatform(),
  @visibleForTesting
  ProcessManager processManager = const LocalProcessManager(),
}) async {
  final RegExp gitBranchRegexp = RegExp(r'^## (.*)');
  final String? luciBranch = platform.environment['LUCI_BRANCH'];
  if (luciBranch != null && luciBranch.trim().isNotEmpty) {
    return luciBranch.trim();
  }
  final ProcessResult gitResult =
      processManager.runSync(<String>['git', 'status', '-b', '--porcelain']);
  if (gitResult.exitCode != 0) {
    throw 'git status exit with non-zero exit code: ${gitResult.exitCode}';
  }
  final RegExpMatch? gitBranchMatch = gitBranchRegexp
      .firstMatch((gitResult.stdout as String).trim().split('\n').first);
  return gitBranchMatch == null
      ? ''
      : gitBranchMatch.group(1)!.split('...').first;
}

Future<void> createFooter(File footerFile, String version,
    {@visibleForTesting String? timestampParam,
    @visibleForTesting String? branchParam,
    @visibleForTesting String? revisionParam}) async {
  final String timestamp =
      timestampParam ?? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
  final String gitBranch = branchParam ?? await getBranchName();
  final String revision = revisionParam ?? await gitRevision();
  final String gitBranchOut = gitBranch.isEmpty ? '' : '• $gitBranch';
  footerFile.writeAsStringSync('''
(function() {
  var span = document.querySelector('footer>span');
  if (span) {
    span.innerText = 'Flutter $version • $timestamp • $revision $gitBranchOut';
  }
  var sourceLink = document.querySelector('a.source-link');
  if (sourceLink) {
    sourceLink.href = sourceLink.href.replace('/master/', '/$revision/');
  }
})();
''');
}
