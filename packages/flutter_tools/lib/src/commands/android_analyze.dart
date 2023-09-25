
import 'dart:async';

import '../base/file_system.dart';
import '../base/logger.dart';
import '../convert.dart';
import '../project.dart';

enum AndroidAnalyzeOption {
  listBuildVariant,

  outputAppLinkSettings,
}

class AndroidAnalyze {
  AndroidAnalyze({
    required this.fileSystem,
    required this.option,
    required this.userPath,
    this.buildVariant,
    required this.logger,
  }) : assert(option == AndroidAnalyzeOption.listBuildVariant || buildVariant != null);

  final FileSystem fileSystem;
  final AndroidAnalyzeOption option;
  final String? buildVariant;
  final String userPath;
  final Logger logger;

  Future<void> analyze() async {
    final FlutterProject project = FlutterProject.fromDirectory(fileSystem.directory(userPath));
    switch (option) {
      case AndroidAnalyzeOption.listBuildVariant:
        logger.printStatus(jsonEncode(await project.android.getBuildVariants()));
      case AndroidAnalyzeOption.outputAppLinkSettings:
        assert(buildVariant != null);
        await project.android.outputsAppLinkSettings(variant: buildVariant!);
        final String filePath = fileSystem.path.join(project.directory.path, 'build', 'app', 'app-link-settings-$buildVariant.json`');
        logger.printStatus('result saved in $filePath');
    }
  }
}