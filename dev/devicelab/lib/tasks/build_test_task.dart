import 'dart:io';

import 'package:args/args.dart';

import '../framework/devices.dart';
import '../framework/task_result.dart';
import '../framework/utils.dart';

abstract class BuildTestTask {
  BuildTestTask(this.args, {this.workingDirectory, this.runFlutterClean = true,}) {
    final ArgResults argResults = argParser.parse(args);
    applicationBinaryPath = argResults[kApplicationBinaryPathOption] as String?;
    buildOnly = argResults[kBuildOnlyFlag] as bool;
    testOnly = argResults[kTestOnlyFlag] as bool;
  }

  static const String kApplicationBinaryPathOption = 'application-binary-path';
  static const String kBuildOnlyFlag = 'build';
  static const String kTestOnlyFlag = 'test';

  final ArgParser argParser = ArgParser()
    ..addOption(kApplicationBinaryPathOption)
    ..addFlag(kBuildOnlyFlag)
    ..addFlag(kTestOnlyFlag);

  final List<String> args;

  bool buildOnly = false;

  bool testOnly = false;

  final bool runFlutterClean;

  String? applicationBinaryPath;

  final Directory? workingDirectory;

  Future<void> build() async {
    await inDirectory<void>(workingDirectory, () async {
      if (runFlutterClean) {
        section('FLUTTER CLEAN');
        await flutter('clean');
      }
      section('BUILDING APPLICATION');
      await flutter('build', options: getBuildArgs(deviceOperatingSystem));
      copyArtifacts();
    });

  }

  Future<TaskResult> test() async {
    final Device device = await devices.workingDevice;
    await device.unlock();
    await inDirectory<void>(workingDirectory, () async {
      section('DRIVE START');
      await flutter('drive', options: getTestArgs(deviceOperatingSystem, device.deviceId));
    });

    return parseTaskResult();
  }

  List<String> getBuildArgs(DeviceOperatingSystem deviceOperatingSystem) => throw UnimplementedError('getBuildArgs is not implemented');

  List<String> getTestArgs(DeviceOperatingSystem deviceOperatingSystem, String deviceId) => throw UnimplementedError('getTestArgs is not implemented');

  void copyArtifacts() => throw UnimplementedError('copyArtifacts is not implemented');

  Future<TaskResult> parseTaskResult() => throw UnimplementedError('parseTaskResult is not implemented');

  String? getApplicationBinaryPath() => applicationBinaryPath;

  Future<TaskResult> call() async {
    if (buildOnly && testOnly) {
      throw Exception('Both build and test should not be passed. Pass only one.');
    }

    if (!testOnly) {
      await build();
    }

    if (buildOnly) {
      return TaskResult.buildOnly();
    }

    return test();
  }
}