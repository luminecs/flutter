import 'dart:async';

import '../base/logger.dart';
import '../convert.dart';
import '../ios/xcodeproj.dart';
import '../project.dart';

enum IOSAnalyzeOption {
  listBuildOptions,

  outputUniversalLinkSettings,
}

class IOSAnalyze {
  IOSAnalyze({
    required this.project,
    required this.option,
    this.configuration,
    this.target,
    required this.logger,
  }) : assert(option == IOSAnalyzeOption.listBuildOptions ||
            (configuration != null && target != null));

  final FlutterProject project;
  final IOSAnalyzeOption option;
  final String? configuration;
  final String? target;
  final Logger logger;

  Future<void> analyze() async {
    switch (option) {
      case IOSAnalyzeOption.listBuildOptions:
        final XcodeProjectInfo? info = await project.ios.projectInfo();
        final Map<String, List<String>> result;
        if (info == null) {
          result = const <String, List<String>>{};
        } else {
          result = <String, List<String>>{
            'configurations': info.buildConfigurations,
            'targets': info.targets,
          };
        }
        logger.printStatus(jsonEncode(result));
      case IOSAnalyzeOption.outputUniversalLinkSettings:
        final String filePath = await project.ios.outputsUniversalLinkSettings(
          configuration: configuration!,
          target: target!,
        );
        logger.printStatus('result saved in $filePath');
    }
  }
}
