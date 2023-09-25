
import 'dart:async';

import 'package:dds/dds.dart' as dds;
import 'package:meta/meta.dart';
import 'package:package_config/package_config.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import 'application_package.dart';
import 'artifacts.dart';
import 'asset.dart';
import 'base/command_help.dart';
import 'base/common.dart';
import 'base/context.dart';
import 'base/file_system.dart';
import 'base/io.dart' as io;
import 'base/logger.dart';
import 'base/platform.dart';
import 'base/signals.dart';
import 'base/terminal.dart';
import 'base/utils.dart';
import 'build_info.dart';
import 'build_system/build_system.dart';
import 'build_system/targets/dart_plugin_registrant.dart';
import 'build_system/targets/localizations.dart';
import 'build_system/targets/scene_importer.dart';
import 'build_system/targets/shader_compiler.dart';
import 'bundle.dart';
import 'cache.dart';
import 'compile.dart';
import 'convert.dart';
import 'devfs.dart';
import 'device.dart';
import 'globals.dart' as globals;
import 'ios/application_package.dart';
import 'ios/devices.dart';
import 'project.dart';
import 'resident_devtools_handler.dart';
import 'run_cold.dart';
import 'run_hot.dart';
import 'sksl_writer.dart';
import 'vmservice.dart';

class FlutterDevice {
  FlutterDevice(
    this.device, {
    required this.buildInfo,
    TargetModel targetModel = TargetModel.flutter,
    this.targetPlatform,
    ResidentCompiler? generator,
    this.userIdentifier,
    required this.developmentShaderCompiler,
    this.developmentSceneImporter,
  }) : generator = generator ?? ResidentCompiler(
         globals.artifacts!.getArtifactPath(
           Artifact.flutterPatchedSdkPath,
           platform: targetPlatform,
           mode: buildInfo.mode,
         ),
         buildMode: buildInfo.mode,
         trackWidgetCreation: buildInfo.trackWidgetCreation,
         fileSystemRoots: buildInfo.fileSystemRoots,
         fileSystemScheme: buildInfo.fileSystemScheme,
         targetModel: targetModel,
         dartDefines: buildInfo.dartDefines,
         packagesPath: buildInfo.packagesPath,
         frontendServerStarterPath: buildInfo.frontendServerStarterPath,
         extraFrontEndOptions: buildInfo.extraFrontEndOptions,
         artifacts: globals.artifacts!,
         processManager: globals.processManager,
         logger: globals.logger,
         platform: globals.platform,
         fileSystem: globals.fs,
       );

  static Future<FlutterDevice> create(
    Device device, {
    required String? target,
    required BuildInfo buildInfo,
    required Platform platform,
    TargetModel targetModel = TargetModel.flutter,
    List<String>? experimentalFlags,
    String? userIdentifier,
  }) async {
    final TargetPlatform targetPlatform = await device.targetPlatform;
    if (device.platformType == PlatformType.fuchsia) {
      targetModel = TargetModel.flutterRunner;
    }
    final DevelopmentShaderCompiler shaderCompiler = DevelopmentShaderCompiler(
      shaderCompiler: ShaderCompiler(
        artifacts: globals.artifacts!,
        logger: globals.logger,
        processManager: globals.processManager,
        fileSystem: globals.fs,
      ),
      fileSystem: globals.fs,
    );

    final DevelopmentSceneImporter sceneImporter = DevelopmentSceneImporter(
      sceneImporter: SceneImporter(
        artifacts: globals.artifacts!,
        logger: globals.logger,
        processManager: globals.processManager,
        fileSystem: globals.fs,
      ),
      fileSystem: globals.fs,
    );

    final ResidentCompiler generator;

    // For both web and non-web platforms we initialize dill to/from
    // a shared location for faster bootstrapping. If the compiler fails
    // due to a kernel target or version mismatch, no error is reported
    // and the compiler starts up as normal. Unexpected errors will print
    // a warning message and dump some debug information which can be
    // used to file a bug, but the compiler will still start up correctly.
    if (targetPlatform == TargetPlatform.web_javascript) {
      // TODO(zanderso): consistently provide these flags across platforms.
      final String platformDillName;
      final List<String> extraFrontEndOptions = List<String>.of(buildInfo.extraFrontEndOptions);
      if (buildInfo.nullSafetyMode == NullSafetyMode.unsound) {
        platformDillName = 'ddc_outline.dill';
        if (!extraFrontEndOptions.contains('--no-sound-null-safety')) {
          extraFrontEndOptions.add('--no-sound-null-safety');
        }
      } else if (buildInfo.nullSafetyMode == NullSafetyMode.sound) {
        platformDillName = 'ddc_outline_sound.dill';
        if (!extraFrontEndOptions.contains('--sound-null-safety')) {
          extraFrontEndOptions.add('--sound-null-safety');
        }
      } else {
        throw StateError('Expected buildInfo.nullSafetyMode to be one of unsound or sound, got ${buildInfo.nullSafetyMode}');
      }

      final String platformDillPath = globals.fs.path.join(
        getWebPlatformBinariesDirectory(globals.artifacts!, buildInfo.webRenderer).path,
        platformDillName,
      );

      generator = ResidentCompiler(
        globals.artifacts!.getHostArtifact(HostArtifact.flutterWebSdk).path,
        buildMode: buildInfo.mode,
        trackWidgetCreation: buildInfo.trackWidgetCreation,
        fileSystemRoots: buildInfo.fileSystemRoots,
        // Override the filesystem scheme so that the frontend_server can find
        // the generated entrypoint code.
        fileSystemScheme: 'org-dartlang-app',
        initializeFromDill: buildInfo.initializeFromDill ?? getDefaultCachedKernelPath(
          trackWidgetCreation: buildInfo.trackWidgetCreation,
          dartDefines: buildInfo.dartDefines,
          extraFrontEndOptions: extraFrontEndOptions,
        ),
        assumeInitializeFromDillUpToDate: buildInfo.assumeInitializeFromDillUpToDate,
        targetModel: TargetModel.dartdevc,
        frontendServerStarterPath: buildInfo.frontendServerStarterPath,
        extraFrontEndOptions: extraFrontEndOptions,
        platformDill: globals.fs.file(platformDillPath).absolute.uri.toString(),
        dartDefines: buildInfo.dartDefines,
        librariesSpec: globals.fs.file(globals.artifacts!
          .getHostArtifact(HostArtifact.flutterWebLibrariesJson)).uri.toString(),
        packagesPath: buildInfo.packagesPath,
        artifacts: globals.artifacts!,
        processManager: globals.processManager,
        logger: globals.logger,
        fileSystem: globals.fs,
        platform: platform,
      );
    } else {
      List<String> extraFrontEndOptions = buildInfo.extraFrontEndOptions;
      extraFrontEndOptions = <String>[
        '--enable-experiment=alternative-invalidation-strategy',
        ...extraFrontEndOptions,
      ];
      generator = ResidentCompiler(
        globals.artifacts!.getArtifactPath(
          Artifact.flutterPatchedSdkPath,
          platform: targetPlatform,
          mode: buildInfo.mode,
        ),
        buildMode: buildInfo.mode,
        trackWidgetCreation: buildInfo.trackWidgetCreation,
        fileSystemRoots: buildInfo.fileSystemRoots,
        fileSystemScheme: buildInfo.fileSystemScheme,
        targetModel: targetModel,
        dartDefines: buildInfo.dartDefines,
        frontendServerStarterPath: buildInfo.frontendServerStarterPath,
        extraFrontEndOptions: extraFrontEndOptions,
        initializeFromDill: buildInfo.initializeFromDill ?? getDefaultCachedKernelPath(
          trackWidgetCreation: buildInfo.trackWidgetCreation,
          dartDefines: buildInfo.dartDefines,
          extraFrontEndOptions: extraFrontEndOptions,
        ),
        assumeInitializeFromDillUpToDate: buildInfo.assumeInitializeFromDillUpToDate,
        packagesPath: buildInfo.packagesPath,
        artifacts: globals.artifacts!,
        processManager: globals.processManager,
        logger: globals.logger,
        platform: platform,
        fileSystem: globals.fs,
      );
    }

    return FlutterDevice(
      device,
      targetModel: targetModel,
      targetPlatform: targetPlatform,
      generator: generator,
      buildInfo: buildInfo,
      userIdentifier: userIdentifier,
      developmentShaderCompiler: shaderCompiler,
      developmentSceneImporter: sceneImporter,
    );
  }

  final TargetPlatform? targetPlatform;
  final Device? device;
  final ResidentCompiler? generator;
  final BuildInfo buildInfo;
  final String? userIdentifier;
  final DevelopmentShaderCompiler developmentShaderCompiler;
  final DevelopmentSceneImporter? developmentSceneImporter;

  DevFSWriter? devFSWriter;
  Stream<Uri?>? vmServiceUris;
  FlutterVmService? vmService;
  DevFS? devFS;
  ApplicationPackage? package;
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _loggingSubscription;
  bool? _isListeningForVmServiceUri;

  bool get isWaitingForVmService => _isListeningForVmServiceUri ?? false;

  Future<void> connect({
    ReloadSources? reloadSources,
    Restart? restart,
    CompileExpression? compileExpression,
    GetSkSLMethod? getSkSLMethod,
    PrintStructuredErrorLogMethod? printStructuredErrorLogMethod,
    int? hostVmServicePort,
    int? ddsPort,
    bool disableServiceAuthCodes = false,
    bool cacheStartupProfile = false,
    bool enableDds = true,
    required bool allowExistingDdsInstance,
    bool ipv6 = false,
  }) {
    final Completer<void> completer = Completer<void>();
    late StreamSubscription<void> subscription;
    bool isWaitingForVm = false;

    subscription = vmServiceUris!.listen((Uri? vmServiceUri) async {
      // FYI, this message is used as a sentinel in tests.
      globals.printTrace('Connecting to service protocol: $vmServiceUri');
      isWaitingForVm = true;
      bool existingDds = false;
      FlutterVmService? service;
      if (enableDds) {
        void handleError(Exception e, StackTrace st) {
          globals.printTrace('Fail to connect to service protocol: $vmServiceUri: $e');
          if (!completer.isCompleted) {
            completer.completeError('failed to connect to $vmServiceUri', st);
          }
        }
        // First check if the VM service is actually listening on vmServiceUri as
        // this may not be the case when scraping logcat for URIs. If this URI is
        // from an old application instance, we shouldn't try and start DDS.
        try {
          service = await connectToVmService(vmServiceUri!, logger: globals.logger);
          await service.dispose();
        } on Exception catch (exception) {
          globals.printTrace('Fail to connect to service protocol: $vmServiceUri: $exception');
          if (!completer.isCompleted && !_isListeningForVmServiceUri!) {
            completer.completeError('failed to connect to $vmServiceUri');
          }
          return;
        }

        // This first try block is meant to catch errors that occur during DDS startup
        // (e.g., failure to bind to a port, failure to connect to the VM service,
        // attaching to a VM service with existing clients, etc.).
        try {
          await device!.dds.startDartDevelopmentService(
            vmServiceUri,
            hostPort: ddsPort,
            ipv6: ipv6,
            disableServiceAuthCodes: disableServiceAuthCodes,
            logger: globals.logger,
            cacheStartupProfile: cacheStartupProfile,
          );
        } on dds.DartDevelopmentServiceException catch (e, st) {
          if (!allowExistingDdsInstance ||
              (e.errorCode != dds.DartDevelopmentServiceException.existingDdsInstanceError)) {
            handleError(e, st);
            return;
          } else {
            existingDds = true;
          }
        } on ToolExit {
          rethrow;
        } on Exception catch (e, st) {
          handleError(e, st);
          return;
        }
      }
      // This second try block handles cases where the VM service connection goes down
      // before flutter_tools connects to DDS. The DDS `done` future completes when DDS
      // shuts down, including after an error. If `done` completes before `connectToVmService`,
      // something went wrong that caused DDS to shutdown early.
      try {
        service = await Future.any<dynamic>(
          <Future<dynamic>>[
            connectToVmService(
              enableDds ? (device!.dds.uri ?? vmServiceUri!): vmServiceUri!,
              reloadSources: reloadSources,
              restart: restart,
              compileExpression: compileExpression,
              getSkSLMethod: getSkSLMethod,
              flutterProject: FlutterProject.current(),
              printStructuredErrorLogMethod: printStructuredErrorLogMethod,
              device: device,
              logger: globals.logger,
            ),
            if (!existingDds)
              device!.dds.done.whenComplete(() => throw Exception('DDS shut down too early')),
          ]
        ) as FlutterVmService?;
      } on Exception catch (exception) {
        globals.printTrace('Fail to connect to service protocol: $vmServiceUri: $exception');
        if (!completer.isCompleted && !_isListeningForVmServiceUri!) {
          completer.completeError('failed to connect to $vmServiceUri');
        }
        return;
      }
      if (completer.isCompleted) {
        return;
      }
      globals.printTrace('Successfully connected to service protocol: $vmServiceUri');

      vmService = service;
      (await device!.getLogReader(app: package)).connectedVMService = vmService;
      completer.complete();
      await subscription.cancel();
    }, onError: (dynamic error) {
      globals.printTrace('Fail to handle VM Service URI: $error');
    }, onDone: () {
      _isListeningForVmServiceUri = false;
      if (!completer.isCompleted && !isWaitingForVm) {
        completer.completeError(Exception('connection to device ended too early'));
      }
    });
    _isListeningForVmServiceUri = true;
    return completer.future;
  }

  Future<void> exitApps({
    @visibleForTesting Duration timeoutDelay = const Duration(seconds: 10),
  }) async {
    // TODO(zanderso): https://github.com/flutter/flutter/issues/83127
    // When updating `flutter attach` to support running without a device,
    // this will need to be changed to fall back to io exit.
    await device!.stopApp(package, userIdentifier: userIdentifier);
  }

  Future<Uri?> setupDevFS(
    String fsName,
    Directory rootDirectory,
  ) {
    // One devFS per device. Shared by all running instances.
    devFS = DevFS(
      vmService!,
      fsName,
      rootDirectory,
      osUtils: globals.os,
      fileSystem: globals.fs,
      logger: globals.logger,
    );
    return devFS!.create();
  }

  Future<void> startEchoingDeviceLog(DebuggingOptions debuggingOptions) async {
    if (_loggingSubscription != null) {
      return;
    }
    final Stream<String> logStream;
    if (device is IOSDevice) {
      logStream = (device! as IOSDevice).getLogReader(
        app: package as IOSApp?,
        usingCISystem: debuggingOptions.usingCISystem,
      ).logLines;
    } else {
      logStream = (await device!.getLogReader(app: package)).logLines;
    }
    _loggingSubscription = logStream.listen((String line) {
      if (!line.contains(globals.kVMServiceMessageRegExp)) {
        globals.printStatus(line, wrap: false);
      }
    });
  }

  Future<void> stopEchoingDeviceLog() async {
    if (_loggingSubscription == null) {
      return;
    }
    await _loggingSubscription!.cancel();
    _loggingSubscription = null;
  }

  Future<void> initLogReader() async {
    final vm_service.VM vm = await vmService!.service.getVM();
    final DeviceLogReader logReader = await device!.getLogReader(app: package);
    logReader.appPid = vm.pid;
  }

  Future<int> runHot({
    required HotRunner hotRunner,
    String? route,
  }) async {
    final bool prebuiltMode = hotRunner.applicationBinary != null;
    final String modeName = hotRunner.debuggingOptions.buildInfo.friendlyModeName;
    globals.printStatus(
      'Launching ${getDisplayPath(hotRunner.mainPath, globals.fs)} '
      'on ${device!.name} in $modeName mode...',
    );

    final TargetPlatform targetPlatform = await device!.targetPlatform;
    package = await ApplicationPackageFactory.instance!.getPackageForPlatform(
      targetPlatform,
      buildInfo: hotRunner.debuggingOptions.buildInfo,
      applicationBinary: hotRunner.applicationBinary,
    );
    final ApplicationPackage? applicationPackage = package;

    if (applicationPackage == null) {
      String message = 'No application found for $targetPlatform.';
      final String? hint = await getMissingPackageHintForPlatform(targetPlatform);
      if (hint != null) {
        message += '\n$hint';
      }
      globals.printError(message);
      return 1;
    }
    devFSWriter = device!.createDevFSWriter(applicationPackage, userIdentifier);

    final Map<String, dynamic> platformArgs = <String, dynamic>{
      'multidex': hotRunner.multidexEnabled,
    };

    await startEchoingDeviceLog(hotRunner.debuggingOptions);

    // Start the application.
    final Future<LaunchResult> futureResult = device!.startApp(
      applicationPackage,
      mainPath: hotRunner.mainPath,
      debuggingOptions: hotRunner.debuggingOptions,
      platformArgs: platformArgs,
      route: route,
      prebuiltApplication: prebuiltMode,
      ipv6: hotRunner.ipv6!,
      userIdentifier: userIdentifier,
    );

    final LaunchResult result = await futureResult;

    if (!result.started) {
      globals.printError('Error launching application on ${device!.name}.');
      await stopEchoingDeviceLog();
      return 2;
    }
    if (result.hasVmService) {
      vmServiceUris = Stream<Uri?>
        .value(result.vmServiceUri)
        .asBroadcastStream();
    } else {
      vmServiceUris = const Stream<Uri>
        .empty()
        .asBroadcastStream();
    }
    return 0;
  }

  Future<int> runCold({
    required ColdRunner coldRunner,
    String? route,
  }) async {
    final TargetPlatform targetPlatform = await device!.targetPlatform;
    package = await ApplicationPackageFactory.instance!.getPackageForPlatform(
      targetPlatform,
      buildInfo: coldRunner.debuggingOptions.buildInfo,
      applicationBinary: coldRunner.applicationBinary,
    );
    final ApplicationPackage? applicationPackage = package;

    if (applicationPackage == null) {
      String message = 'No application found for $targetPlatform.';
      final String? hint = await getMissingPackageHintForPlatform(targetPlatform);
      if (hint != null) {
        message += '\n$hint';
      }
      globals.printError(message);
      return 1;
    }

    devFSWriter = device!.createDevFSWriter(applicationPackage, userIdentifier);

    final String modeName = coldRunner.debuggingOptions.buildInfo.friendlyModeName;
    final bool prebuiltMode = coldRunner.applicationBinary != null;
    globals.printStatus(
      'Launching ${getDisplayPath(coldRunner.mainPath, globals.fs)} '
      'on ${device!.name} in $modeName mode...',
    );

    final Map<String, dynamic> platformArgs = <String, dynamic>{};
    platformArgs['trace-startup'] = coldRunner.traceStartup;
    platformArgs['multidex'] = coldRunner.multidexEnabled;

    await startEchoingDeviceLog(coldRunner.debuggingOptions);

    final LaunchResult result = await device!.startApp(
      applicationPackage,
      mainPath: coldRunner.mainPath,
      debuggingOptions: coldRunner.debuggingOptions,
      platformArgs: platformArgs,
      route: route,
      prebuiltApplication: prebuiltMode,
      ipv6: coldRunner.ipv6!,
      userIdentifier: userIdentifier,
    );

    if (!result.started) {
      globals.printError('Error running application on ${device!.name}.');
      await stopEchoingDeviceLog();
      return 2;
    }
    if (result.hasVmService) {
      vmServiceUris = Stream<Uri?>
        .value(result.vmServiceUri)
        .asBroadcastStream();
    } else {
      vmServiceUris = const Stream<Uri>
        .empty()
        .asBroadcastStream();
    }
    return 0;
  }

  Future<UpdateFSReport> updateDevFS({
    required Uri mainUri,
    String? target,
    AssetBundle? bundle,
    DateTime? firstBuildTime,
    bool bundleFirstUpload = false,
    bool bundleDirty = false,
    bool fullRestart = false,
    String? projectRootPath,
    required String pathToReload,
    required String dillOutputPath,
    required List<Uri> invalidatedFiles,
    required PackageConfig packageConfig,
  }) async {
    final Status devFSStatus = globals.logger.startProgress(
      'Syncing files to device ${device!.name}...',
    );
    UpdateFSReport report;
    try {
      report = await devFS!.update(
        mainUri: mainUri,
        target: target,
        bundle: bundle,
        firstBuildTime: firstBuildTime,
        bundleFirstUpload: bundleFirstUpload,
        generator: generator!,
        fullRestart: fullRestart,
        dillOutputPath: dillOutputPath,
        trackWidgetCreation: buildInfo.trackWidgetCreation,
        projectRootPath: projectRootPath,
        pathToReload: pathToReload,
        invalidatedFiles: invalidatedFiles,
        packageConfig: packageConfig,
        devFSWriter: devFSWriter,
        shaderCompiler: developmentShaderCompiler,
        sceneImporter: developmentSceneImporter,
        dartPluginRegistrant: FlutterProject.current().dartPluginRegistrant,
      );
    } on DevFSException {
      devFSStatus.cancel();
      return UpdateFSReport();
    }
    devFSStatus.stop();
    globals.printTrace('Synced ${getSizeAsMB(report.syncedBytes)}.');
    return report;
  }

  Future<void> updateReloadStatus(bool wasReloadSuccessful) async {
    if (wasReloadSuccessful) {
      generator?.accept();
    } else {
      await generator?.reject();
    }
  }
}

abstract class ResidentHandlers {
  List<FlutterDevice?> get flutterDevices;

  bool get hotMode;

  bool get supportsServiceProtocol;

  bool get isRunningDebug;

  bool get isRunningProfile;

  bool get isRunningRelease;

  bool get stayResident;

  bool get supportsRestart;

  bool get supportsWriteSkSL;

  bool get canHotReload;

  ResidentDevtoolsHandler? get residentDevtoolsHandler;

  @protected
  Logger get logger;

  @protected
  FileSystem? get fileSystem;

  void printHelp({ required bool details });

  Future<OperationResult> restart({ bool fullRestart = false, bool pause = false, String? reason }) {
    final String mode = isRunningProfile ? 'profile' :isRunningRelease ? 'release' : 'this';
    throw Exception('${fullRestart ? 'Restart' : 'Reload'} is not supported in $mode mode');
  }

  Future<bool> debugDumpApp() async {
    if (!supportsServiceProtocol) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        final String data = await device.vmService!.flutterDebugDumpApp(
          isolateId: view.uiIsolate!.id!,
        );
        logger.printStatus(data);
      }
    }
    return true;
  }

  Future<bool> debugDumpRenderTree() async {
    if (!supportsServiceProtocol) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        final String data = await device.vmService!.flutterDebugDumpRenderTree(
          isolateId: view.uiIsolate!.id!,
        );
        logger.printStatus(data);
      }
    }
    return true;
  }

  Future<bool> debugFrameJankMetrics() async {
    if (!supportsServiceProtocol) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      if (device?.targetPlatform == TargetPlatform.web_javascript) {
        logger.printWarning('Unable to get jank metrics for web');
        continue;
      }
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        final Map<String, Object?>? rasterData =
          await device.vmService!.renderFrameWithRasterStats(
            viewId: view.id,
            uiIsolateId: view.uiIsolate!.id,
          );
        if (rasterData != null) {
          final File tempFile = globals.fsUtils.getUniqueFile(
            globals.fs.currentDirectory,
            'flutter_jank_metrics',
            'json',
          );
          tempFile.writeAsStringSync(jsonEncode(rasterData), flush: true);
          logger.printStatus('Wrote jank metrics to ${tempFile.absolute.path}');
        } else {
          logger.printWarning('Unable to get jank metrics.');
        }
      }
    }
    return true;
  }

  Future<bool> debugDumpLayerTree() async {
    if (!supportsServiceProtocol || !isRunningDebug) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        final String data = await device.vmService!.flutterDebugDumpLayerTree(
          isolateId: view.uiIsolate!.id!,
        );
        logger.printStatus(data);
      }
    }
    return true;
  }

  Future<bool> debugDumpFocusTree() async {
    if (!supportsServiceProtocol || !isRunningDebug) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        final String data = await device.vmService!.flutterDebugDumpFocusTree(
          isolateId: view.uiIsolate!.id!,
        );
        logger.printStatus(data);
      }
    }
    return true;
  }

  Future<bool> debugDumpSemanticsTreeInTraversalOrder() async {
    if (!supportsServiceProtocol) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        final String data = await device.vmService!.flutterDebugDumpSemanticsTreeInTraversalOrder(
          isolateId: view.uiIsolate!.id!,
        );
        logger.printStatus(data);
      }
    }
    return true;
  }

  Future<bool> debugDumpSemanticsTreeInInverseHitTestOrder() async {
    if (!supportsServiceProtocol) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        final String data = await device.vmService!.flutterDebugDumpSemanticsTreeInInverseHitTestOrder(
          isolateId: view.uiIsolate!.id!,
        );
        logger.printStatus(data);
      }
    }
    return true;
  }

  Future<bool> debugToggleDebugPaintSizeEnabled() async {
    if (!supportsServiceProtocol || !isRunningDebug) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        await device.vmService!.flutterToggleDebugPaintSizeEnabled(
          isolateId: view.uiIsolate!.id!,
        );
      }
    }
    return true;
  }

  Future<bool> debugTogglePerformanceOverlayOverride() async {
    if (!supportsServiceProtocol) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      if (device!.targetPlatform == TargetPlatform.web_javascript) {
        continue;
      }
      final List<FlutterView> views = await device.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        await device.vmService!.flutterTogglePerformanceOverlayOverride(
          isolateId: view.uiIsolate!.id!,
        );
      }
    }
    return true;
  }

  Future<bool> debugToggleWidgetInspector() async {
    if (!supportsServiceProtocol) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        await device.vmService!.flutterToggleWidgetInspector(
          isolateId: view.uiIsolate!.id!,
        );
      }
    }
    return true;
  }

  Future<bool> debugToggleInvertOversizedImages() async {
    if (!supportsServiceProtocol || !isRunningDebug) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        await device.vmService!.flutterToggleInvertOversizedImages(
          isolateId: view.uiIsolate!.id!,
        );
      }
    }
    return true;
  }

  Future<bool> debugToggleProfileWidgetBuilds() async {
    if (!supportsServiceProtocol) {
      return false;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        await device.vmService!.flutterToggleProfileWidgetBuilds(
          isolateId: view.uiIsolate!.id!,
        );
      }
    }
    return true;
  }

  Future<bool> debugToggleBrightness() async {
    if (!supportsServiceProtocol) {
      return false;
    }
    final List<FlutterView> views = await flutterDevices.first!.vmService!.getFlutterViews();
    final Brightness? current = await flutterDevices.first!.vmService!.flutterBrightnessOverride(
      isolateId: views.first.uiIsolate!.id!,
    );
    Brightness next;
    if (current == Brightness.light) {
      next = Brightness.dark;
    } else {
      next = Brightness.light;
    }
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        await device.vmService!.flutterBrightnessOverride(
          isolateId: view.uiIsolate!.id!,
          brightness: next,
        );
      }
      logger.printStatus('Changed brightness to $next.');
    }
    return true;
  }

  Future<bool> debugTogglePlatform() async {
    if (!supportsServiceProtocol || !isRunningDebug) {
      return false;
    }
    final List<FlutterView> views = await flutterDevices.first!.vmService!.getFlutterViews();
    final String from = await flutterDevices
      .first!.vmService!.flutterPlatformOverride(
        isolateId: views.first.uiIsolate!.id!,
      );
    final String to = nextPlatform(from);
    for (final FlutterDevice? device in flutterDevices) {
      final List<FlutterView> views = await device!.vmService!.getFlutterViews();
      for (final FlutterView view in views) {
        await device.vmService!.flutterPlatformOverride(
          platform: to,
          isolateId: view.uiIsolate!.id!,
        );
      }
    }
    logger.printStatus('Switched operating system to $to');
    return true;
  }

  Future<String?> writeSkSL() async {
    if (!supportsWriteSkSL) {
      throw Exception('writeSkSL is not supported by this runner.');
    }
    final FlutterDevice flutterDevice = flutterDevices.first!;
    final FlutterVmService vmService = flutterDevice.vmService!;
    final List<FlutterView> views = await vmService.getFlutterViews();
    final Map<String, Object?>? data = await vmService.getSkSLs(
      viewId: views.first.id,
    );
    final Device device = flutterDevice.device!;
    return sharedSkSlWriter(device, data);
  }

  Future<void> screenshot(FlutterDevice device) async {
    if (!device.device!.supportsScreenshot && !supportsServiceProtocol) {
      return;
    }
    final Status status = logger.startProgress(
      'Taking screenshot for ${device.device!.name}...',
    );
    final File outputFile = getUniqueFile(
      fileSystem!.currentDirectory,
      'flutter',
      'png',
    );

    try {
      bool result;
      if (device.device!.supportsScreenshot) {
        result = await _toggleDebugBanner(device, () => device.device!.takeScreenshot(outputFile));
      } else {
        result = await _takeVmServiceScreenshot(device, outputFile);
      }
      if (!result) {
        return;
      }
      final int sizeKB = outputFile.lengthSync() ~/ 1024;
      status.stop();
      logger.printStatus(
        'Screenshot written to ${fileSystem!.path.relative(outputFile.path)} (${sizeKB}kB).',
      );
    } on Exception catch (error) {
      status.cancel();
      logger.printError('Error taking screenshot: $error');
    }
  }

  Future<bool> _takeVmServiceScreenshot(FlutterDevice device, File outputFile) async {
    final bool isWebDevice = device.targetPlatform == TargetPlatform.web_javascript;
    assert(supportsServiceProtocol);

    return _toggleDebugBanner(device, () async {
      final vm_service.Response? response = isWebDevice
        ? await device.vmService!.callMethodWrapper('ext.dwds.screenshot')
        : await device.vmService!.screenshot();
      if (response == null) {
       throw Exception('Failed to take screenshot');
      }
      final String data = response.json![isWebDevice ? 'data' : 'screenshot'] as String;
      outputFile.writeAsBytesSync(base64.decode(data));
    });
  }

  Future<bool> _toggleDebugBanner(FlutterDevice device, Future<void> Function() cb) async {
    List<FlutterView> views = <FlutterView>[];
    if (supportsServiceProtocol) {
      views = await device.vmService!.getFlutterViews();
    }

    Future<bool> setDebugBanner(bool value) async {
      try {
        for (final FlutterView view in views) {
          await device.vmService!.flutterDebugAllowBanner(
            value,
            isolateId: view.uiIsolate!.id!,
          );
        }
        return true;
      } on vm_service.RPCError catch (error) {
        logger.printError('Error communicating with Flutter on the device: $error');
        return false;
      }
    }
    if (!await setDebugBanner(false)) {
      return false;
    }
    bool succeeded = true;
    try {
      await cb();
    } finally {
      if (!await setDebugBanner(true)) {
        succeeded = false;
      }
    }
    return succeeded;
  }


  Future<void> cleanupAfterSignal();

  Future<void> detach();

  Future<void> exit();

  Future<void> runSourceGenerators();
}

// Shared code between different resident application runners.
abstract class ResidentRunner extends ResidentHandlers {
  ResidentRunner(
    this.flutterDevices, {
    required this.target,
    required this.debuggingOptions,
    String? projectRootPath,
    this.ipv6,
    this.stayResident = true,
    this.hotMode = true,
    String? dillOutputPath,
    this.machine = false,
    ResidentDevtoolsHandlerFactory devtoolsHandler = createDefaultHandler,
  }) : mainPath = globals.fs.file(target).absolute.path,
       packagesFilePath = debuggingOptions.buildInfo.packagesPath,
       projectRootPath = projectRootPath ?? globals.fs.currentDirectory.path,
       _dillOutputPath = dillOutputPath,
       artifactDirectory = dillOutputPath == null
          ? globals.fs.systemTempDirectory.createTempSync('flutter_tool.')
          : globals.fs.file(dillOutputPath).parent,
       assetBundle = AssetBundleFactory.instance.createBundle(),
       commandHelp = CommandHelp(
         logger: globals.logger,
         terminal: globals.terminal,
         platform: globals.platform,
         outputPreferences: globals.outputPreferences,
       ) {
    if (!artifactDirectory.existsSync()) {
      artifactDirectory.createSync(recursive: true);
    }
    _residentDevtoolsHandler = devtoolsHandler(DevtoolsLauncher.instance, this, globals.logger);
  }

  @override
  Logger get logger => globals.logger;

  @override
  FileSystem get fileSystem => globals.fs;

  @override
  final List<FlutterDevice> flutterDevices;

  final String target;
  final DebuggingOptions debuggingOptions;

  @override
  final bool stayResident;
  final bool? ipv6;
  final String? _dillOutputPath;
  final Directory artifactDirectory;
  final String packagesFilePath;
  final String projectRootPath;
  final String mainPath;
  final AssetBundle assetBundle;

  final CommandHelp commandHelp;
  final bool machine;

  @override
  ResidentDevtoolsHandler? get residentDevtoolsHandler => _residentDevtoolsHandler;
  ResidentDevtoolsHandler? _residentDevtoolsHandler;

  bool _exited = false;
  Completer<int> _finished = Completer<int>();
  BuildResult? _lastBuild;
  Environment? _environment;

  @override
  bool hotMode;

  bool get isWaitingForVmService {
    return flutterDevices.every((FlutterDevice? device) {
      return device!.isWaitingForVmService;
    });
  }

  String get dillOutputPath => _dillOutputPath ?? globals.fs.path.join(artifactDirectory.path, 'app.dill');
  String getReloadPath({
    bool fullRestart = false,
    required bool swap,
  }) {
    if (!fullRestart) {
      return 'main.dart.incremental.dill';
    }
    return 'main.dart${swap ? '.swap' : ''}.dill';
  }

  bool get debuggingEnabled => debuggingOptions.debuggingEnabled;

  @override
  bool get isRunningDebug => debuggingOptions.buildInfo.isDebug;

  @override
  bool get isRunningProfile => debuggingOptions.buildInfo.isProfile;

  @override
  bool get isRunningRelease => debuggingOptions.buildInfo.isRelease;

  @override
  bool get supportsServiceProtocol => isRunningDebug || isRunningProfile;

  @override
  bool get supportsWriteSkSL => supportsServiceProtocol;

  bool get trackWidgetCreation => debuggingOptions.buildInfo.trackWidgetCreation;

  bool get generateDartPluginRegistry => true;

  // Returns the Uri of the first connected device for mobile,
  // and only connected device for web.
  //
  // Would be null if there is no device connected or
  // there is no devFS associated with the first device.
  Uri? get uri => flutterDevices.first.devFS?.baseUri;

  bool get exited => _exited;

  @override
  bool get supportsRestart {
    return isRunningDebug && flutterDevices.every((FlutterDevice? device) {
      return device!.device!.supportsHotRestart;
    });
  }

  @override
  bool get canHotReload => hotMode;

  Future<int?> run({
    Completer<DebugConnectionInfo>? connectionInfoCompleter,
    Completer<void>? appStartedCompleter,
    bool enableDevTools = false,
    String? route,
  });

  Future<int?> attach({
    Completer<DebugConnectionInfo>? connectionInfoCompleter,
    Completer<void>? appStartedCompleter,
    bool allowExistingDdsInstance = false,
    bool enableDevTools = false,
    bool needsFullRestart = true,
  });

  @override
  Future<void> runSourceGenerators() async {
    _environment ??= Environment(
      artifacts: globals.artifacts!,
      logger: globals.logger,
      cacheDir: globals.cache.getRoot(),
      engineVersion: globals.flutterVersion.engineRevision,
      fileSystem: globals.fs,
      flutterRootDir: globals.fs.directory(Cache.flutterRoot),
      outputDir: globals.fs.directory(getBuildDirectory()),
      processManager: globals.processManager,
      platform: globals.platform,
      usage: globals.flutterUsage,
      projectDir: globals.fs.currentDirectory,
      generateDartPluginRegistry: generateDartPluginRegistry,
      defines: <String, String>{
        // Needed for Dart plugin registry generation.
        kTargetFile: mainPath,
      },
    );

    final CompositeTarget compositeTarget = CompositeTarget(<Target>[
      const GenerateLocalizationsTarget(),
      const DartPluginRegistrantTarget(),
    ]);

    _lastBuild = await globals.buildSystem.buildIncremental(
      compositeTarget,
      _environment!,
      _lastBuild,
    );
    if (!_lastBuild!.success) {
      for (final ExceptionMeasurement exceptionMeasurement in _lastBuild!.exceptions.values) {
        globals.printError(
          exceptionMeasurement.exception.toString(),
          stackTrace: globals.logger.isVerbose
            ? exceptionMeasurement.stackTrace
            : null,
        );
      }
    }
    globals.printTrace('complete');
  }

  @protected
  void writeVmServiceFile() {
    if (debuggingOptions.vmserviceOutFile != null) {
      try {
        final String address = flutterDevices.first.vmService!.wsAddress.toString();
        final File vmserviceOutFile = globals.fs.file(debuggingOptions.vmserviceOutFile);
        vmserviceOutFile.createSync(recursive: true);
        vmserviceOutFile.writeAsStringSync(address);
      } on FileSystemException {
        globals.printError('Failed to write vmservice-out-file at ${debuggingOptions.vmserviceOutFile}');
      }
    }
  }

  @override
  Future<void> exit() async {
    _exited = true;
    await residentDevtoolsHandler!.shutdown();
    await stopEchoingDeviceLog();
    await preExit();
    await exitApp(); // calls appFinished
    await shutdownDartDevelopmentService();
  }

  @override
  Future<void> detach() async {
    await residentDevtoolsHandler!.shutdown();
    await stopEchoingDeviceLog();
    await preExit();
    await shutdownDartDevelopmentService();
    appFinished();
  }

  Future<void> stopEchoingDeviceLog() async {
    await Future.wait<void>(
      flutterDevices.map<Future<void>>((FlutterDevice? device) => device!.stopEchoingDeviceLog())
    );
  }

  Future<void> shutdownDartDevelopmentService() async {
    await Future.wait<void>(
      flutterDevices.map<Future<void>>(
        (FlutterDevice? device) => device?.device?.dds.shutdown() ?? Future<void>.value()
      )
    );
  }

  @protected
  void cacheInitialDillCompilation() {
    if (_dillOutputPath != null) {
      return;
    }
    globals.printTrace('Caching compiled dill');
    final File outputDill = globals.fs.file(dillOutputPath);
    if (outputDill.existsSync()) {
      final String copyPath = getDefaultCachedKernelPath(
        trackWidgetCreation: trackWidgetCreation,
        dartDefines: debuggingOptions.buildInfo.dartDefines,
        extraFrontEndOptions: debuggingOptions.buildInfo.extraFrontEndOptions,
      );
      globals.fs
          .file(copyPath)
          .parent
          .createSync(recursive: true);
      outputDill.copySync(copyPath);
    }
  }

  void printStructuredErrorLog(vm_service.Event event) {
    if (event.extensionKind == 'Flutter.Error' && !machine) {
      final Map<String, Object?>? json = event.extensionData?.data;
      if (json != null && json.containsKey('renderedErrorText')) {
        final int errorsSinceReload;
        if (json.containsKey('errorsSinceReload') && json['errorsSinceReload'] is int) {
          errorsSinceReload = json['errorsSinceReload']! as int;
        } else {
          errorsSinceReload = 0;
        }
        if (errorsSinceReload == 0) {
          // We print a blank line around the first error, to more clearly emphasize it
          // in the output. (Other errors don't get this.)
          globals.printStatus('');
        }
        globals.printStatus('${json['renderedErrorText']}');
        if (errorsSinceReload == 0) {
          globals.printStatus('');
        }
      } else {
        globals.printError('Received an invalid ${globals.logger.terminal.bolden("Flutter.Error")} message from app: $json');
      }
    }
  }

  //
  // Failures should be indicated by completing the future with an error, using
  // a string as the error object, which will be used by the caller (attach())
  // to display an error message.
  Future<void> connectToServiceProtocol({
    ReloadSources? reloadSources,
    Restart? restart,
    CompileExpression? compileExpression,
    GetSkSLMethod? getSkSLMethod,
    required bool allowExistingDdsInstance,
  }) async {
    if (!debuggingOptions.debuggingEnabled) {
      throw Exception('The service protocol is not enabled.');
    }
    _finished = Completer<int>();
    // Listen for service protocol connection to close.
    for (final FlutterDevice? device in flutterDevices) {
      await device!.connect(
        reloadSources: reloadSources,
        restart: restart,
        compileExpression: compileExpression,
        enableDds: debuggingOptions.enableDds,
        ddsPort: debuggingOptions.ddsPort,
        allowExistingDdsInstance: allowExistingDdsInstance,
        hostVmServicePort: debuggingOptions.hostVmServicePort,
        getSkSLMethod: getSkSLMethod,
        printStructuredErrorLogMethod: printStructuredErrorLog,
        ipv6: ipv6 ?? false,
        disableServiceAuthCodes: debuggingOptions.disableServiceAuthCodes,
        cacheStartupProfile: debuggingOptions.cacheStartupProfile,
      );
      await device.vmService!.getFlutterViews();

      // This hooks up callbacks for when the connection stops in the future.
      // We don't want to wait for them. We don't handle errors in those callbacks'
      // futures either because they just print to logger and is not critical.
      unawaited(device.vmService!.service.onDone.then<void>(
        _serviceProtocolDone,
        onError: _serviceProtocolError,
      ).whenComplete(_serviceDisconnected));
    }
  }

  Future<void> _serviceProtocolDone(dynamic object) async {
    globals.printTrace('Service protocol connection closed.');
  }

  Future<void> _serviceProtocolError(Object error, StackTrace stack) {
    globals.printTrace('Service protocol connection closed with an error: $error\n$stack');
    return Future<void>.error(error, stack);
  }

  void _serviceDisconnected() {
    if (_exited) {
      // User requested the application exit.
      return;
    }
    if (_finished.isCompleted) {
      return;
    }
    globals.printStatus('Lost connection to device.');
    _finished.complete(0);
  }

  Future<void> enableObservatory() async {
    assert(debuggingOptions.serveObservatory);
    final List<Future<vm_service.Response?>> serveObservatoryRequests = <Future<vm_service.Response?>>[];
    for (final FlutterDevice? device in flutterDevices) {
      if (device == null) {
        continue;
      }
      // Notify the VM service if the user wants Observatory to be served.
      serveObservatoryRequests.add(
        device.vmService?.callMethodWrapper('_serveObservatory') ??
          Future<vm_service.Response?>.value(),
      );
    }
    try {
      await Future.wait(serveObservatoryRequests);
    } on vm_service.RPCError catch (e) {
      globals.printWarning('Unable to enable Observatory: $e');
    }
  }

  void appFinished() {
    if (_finished.isCompleted) {
      return;
    }
    globals.printStatus('Application finished.');
    _finished.complete(0);
  }

  void appFailedToStart() {
    if (!_finished.isCompleted) {
      _finished.complete(1);
    }
  }

  Future<int> waitForAppToFinish() async {
    final int exitCode = await _finished.future;
    await cleanupAtFinish();
    return exitCode;
  }

  @mustCallSuper
  Future<void> preExit() async {
    // If _dillOutputPath is null, the tool created a temporary directory for
    // the dill.
    if (_dillOutputPath == null && artifactDirectory.existsSync()) {
      artifactDirectory.deleteSync(recursive: true);
    }
  }

  Future<void> exitApp() async {
    final List<Future<void>> futures = <Future<void>>[
      for (final FlutterDevice? device in flutterDevices) device!.exitApps(),
    ];
    await Future.wait(futures);
    appFinished();
  }

  bool get reportedDebuggers => _reportedDebuggers;
  bool _reportedDebuggers = false;

  void printDebuggerList({ bool includeVmService = true, bool includeDevtools = true }) {
    final DevToolsServerAddress? devToolsServerAddress = residentDevtoolsHandler!.activeDevToolsServer;
    if (!residentDevtoolsHandler!.readyToAnnounce) {
      includeDevtools = false;
    }
    assert(!includeDevtools || devToolsServerAddress != null);
    for (final FlutterDevice? device in flutterDevices) {
      if (device!.vmService == null) {
        continue;
      }
      if (includeVmService) {
        // Caution: This log line is parsed by device lab tests.
        globals.printStatus(
          'A Dart VM Service on ${device.device!.name} is available at: '
          '${device.vmService!.httpAddress}',
        );
      }
      if (includeDevtools) {
        final Uri? uri = devToolsServerAddress!.uri?.replace(
          queryParameters: <String, dynamic>{'uri': '${device.vmService!.httpAddress}'},
        );
        if (uri != null) {
          globals.printStatus(
            'The Flutter DevTools debugger and profiler '
            'on ${device.device!.name} is available at: ${urlToDisplayString(uri)}',
          );
        }
      }
    }
    _reportedDebuggers = true;
  }

  void printHelpDetails() {
    commandHelp.v.print();
    if (flutterDevices.any((FlutterDevice? d) => d!.device!.supportsScreenshot)) {
      commandHelp.s.print();
    }
    if (supportsServiceProtocol) {
      commandHelp.w.print();
      commandHelp.t.print();
      if (isRunningDebug) {
        commandHelp.L.print();
        commandHelp.f.print();
        commandHelp.S.print();
        commandHelp.U.print();
        commandHelp.i.print();
        commandHelp.p.print();
        commandHelp.I.print();
        commandHelp.o.print();
        commandHelp.b.print();
      } else {
        commandHelp.S.print();
        commandHelp.U.print();
      }
      // Performance related features: `P` should precede `a`, which should precede `M`.
      commandHelp.P.print();
      commandHelp.a.print();
      if (supportsWriteSkSL) {
        commandHelp.M.print();
      }
      if (isRunningDebug) {
        commandHelp.g.print();
      }
      commandHelp.j.print();
    }
  }

  @override
  Future<void> cleanupAfterSignal();

  Future<void> cleanupAtFinish();
}

class OperationResult {
  OperationResult(this.code, this.message, { this.fatal = false, this.updateFSReport, this.extraTimings = const <OperationResultExtraTiming>[] });

  final int code;

  final String message;

  final List<OperationResultExtraTiming> extraTimings;

  final bool fatal;

  final UpdateFSReport? updateFSReport;

  bool get isOk => code == 0;

  static final OperationResult ok = OperationResult(0, '');
}

class OperationResultExtraTiming {
  const OperationResultExtraTiming(this.description, this.timeInMs);

  final String description;

  final int timeInMs;
}

Future<String?> getMissingPackageHintForPlatform(TargetPlatform platform) async {
  switch (platform) {
    case TargetPlatform.android_arm:
    case TargetPlatform.android_arm64:
    case TargetPlatform.android_x64:
    case TargetPlatform.android_x86:
      final FlutterProject project = FlutterProject.current();
      final String manifestPath = globals.fs.path.relative(project.android.appManifestFile.path);
      return 'Is your project missing an $manifestPath?\nConsider running "flutter create ." to create one.';
    case TargetPlatform.ios:
      return 'Is your project missing an ios/Runner/Info.plist?\nConsider running "flutter create ." to create one.';
    case TargetPlatform.android:
    case TargetPlatform.darwin:
    case TargetPlatform.fuchsia_arm64:
    case TargetPlatform.fuchsia_x64:
    case TargetPlatform.linux_arm64:
    case TargetPlatform.linux_x64:
    case TargetPlatform.tester:
    case TargetPlatform.web_javascript:
    case TargetPlatform.windows_x64:
      return null;
  }
}

class TerminalHandler {
  TerminalHandler(this.residentRunner, {
    required Logger logger,
    required Terminal terminal,
    required Signals signals,
    required io.ProcessInfo processInfo,
    required bool reportReady,
    String? pidFile,
  }) : _logger = logger,
       _terminal = terminal,
       _signals = signals,
       _processInfo = processInfo,
       _reportReady = reportReady,
       _pidFile = pidFile;

  final Logger _logger;
  final Terminal _terminal;
  final Signals _signals;
  final io.ProcessInfo _processInfo;
  final bool _reportReady;
  final String? _pidFile;

  final ResidentHandlers residentRunner;
  bool _processingUserRequest = false;
  StreamSubscription<void>? subscription;
  File? _actualPidFile;

  @visibleForTesting
  String? lastReceivedCommand;

  @visibleForTesting
  BufferLogger get logger => _logger as BufferLogger;

  void setupTerminal() {
    if (!_logger.quiet) {
      _logger.printStatus('');
      residentRunner.printHelp(details: false);
    }
    _terminal.singleCharMode = true;
    subscription = _terminal.keystrokes.listen(processTerminalInput);
  }

  final Map<io.ProcessSignal, Object> _signalTokens = <io.ProcessSignal, Object>{};

  void _addSignalHandler(io.ProcessSignal signal, SignalHandler handler) {
    _signalTokens[signal] = _signals.addHandler(signal, handler);
  }

  void registerSignalHandlers() {
    assert(residentRunner.stayResident);
    _addSignalHandler(io.ProcessSignal.sigint, _cleanUp);
    _addSignalHandler(io.ProcessSignal.sigterm, _cleanUp);
    if (residentRunner.supportsServiceProtocol && residentRunner.supportsRestart) {
      _addSignalHandler(io.ProcessSignal.sigusr1, _handleSignal);
      _addSignalHandler(io.ProcessSignal.sigusr2, _handleSignal);
      if (_pidFile != null) {
        _logger.printTrace('Writing pid to: $_pidFile');
        _actualPidFile = _processInfo.writePidFile(_pidFile);
      }
    }
  }

  void stop() {
    assert(residentRunner.stayResident);
    if (_actualPidFile != null) {
      try {
        _logger.printTrace('Deleting pid file (${_actualPidFile!.path}).');
        _actualPidFile!.deleteSync();
      } on FileSystemException catch (error) {
        _logger.printWarning('Failed to delete pid file (${_actualPidFile!.path}): ${error.message}');
      }
      _actualPidFile = null;
    }
    for (final MapEntry<io.ProcessSignal, Object> entry in _signalTokens.entries) {
      _signals.removeHandler(entry.key, entry.value);
    }
    _signalTokens.clear();
    subscription?.cancel();
  }

  Future<bool> _commonTerminalInputHandler(String character) async {
    _logger.printStatus(''); // the key the user tapped might be on this line
    switch (character) {
      case 'a':
        return residentRunner.debugToggleProfileWidgetBuilds();
      case 'b':
        return residentRunner.debugToggleBrightness();
      case 'c':
        _logger.clear();
        return true;
      case 'd':
      case 'D':
        await residentRunner.detach();
        return true;
      case 'f':
        return residentRunner.debugDumpFocusTree();
      case 'g':
        await residentRunner.runSourceGenerators();
        return true;
      case 'h':
      case 'H':
      case '?':
        // help
        residentRunner.printHelp(details: true);
        return true;
      case 'i':
        return residentRunner.debugToggleWidgetInspector();
      case 'I':
        return residentRunner.debugToggleInvertOversizedImages();
      case 'j':
      case 'J':
        return residentRunner.debugFrameJankMetrics();
      case 'L':
        return residentRunner.debugDumpLayerTree();
      case 'o':
      case 'O':
        return residentRunner.debugTogglePlatform();
      case 'M':
        if (residentRunner.supportsWriteSkSL) {
          await residentRunner.writeSkSL();
          return true;
        }
        return false;
      case 'p':
        return residentRunner.debugToggleDebugPaintSizeEnabled();
      case 'P':
        return residentRunner.debugTogglePerformanceOverlayOverride();
      case 'q':
      case 'Q':
        // exit
        await residentRunner.exit();
        return true;
      case 'r':
        if (!residentRunner.canHotReload) {
          return false;
        }
        final OperationResult result = await residentRunner.restart();
        if (result.fatal) {
          throwToolExit(result.message);
        }
        if (!result.isOk) {
          _logger.printStatus('Try again after fixing the above error(s).', emphasis: true);
        }
        return true;
      case 'R':
        // If hot restart is not supported for all devices, ignore the command.
        if (!residentRunner.supportsRestart || !residentRunner.hotMode) {
          return false;
        }
        final OperationResult result = await residentRunner.restart(fullRestart: true);
        if (result.fatal) {
          throwToolExit(result.message);
        }
        if (!result.isOk) {
          _logger.printStatus('Try again after fixing the above error(s).', emphasis: true);
        }
        return true;
      case 's':
        for (final FlutterDevice? device in residentRunner.flutterDevices) {
          await residentRunner.screenshot(device!);
        }
        return true;
      case 'S':
        return residentRunner.debugDumpSemanticsTreeInTraversalOrder();
      case 't':
      case 'T':
        return residentRunner.debugDumpRenderTree();
      case 'U':
        return residentRunner.debugDumpSemanticsTreeInInverseHitTestOrder();
      case 'v':
      case 'V':
        return residentRunner.residentDevtoolsHandler!.launchDevToolsInBrowser(flutterDevices: residentRunner.flutterDevices);
      case 'w':
      case 'W':
        return residentRunner.debugDumpApp();
    }
    return false;
  }

  Future<void> processTerminalInput(String command) async {
    // When terminal doesn't support line mode, '\n' can sneak into the input.
    command = command.trim();
    if (_processingUserRequest) {
      _logger.printTrace('Ignoring terminal input: "$command" because we are busy.');
      return;
    }
    _processingUserRequest = true;
    try {
      lastReceivedCommand = command;
      await _commonTerminalInputHandler(command);
    // Catch all exception since this is doing cleanup and rethrowing.
    } catch (error, st) { // ignore: avoid_catches_without_on_clauses
      // Don't print stack traces for known error types.
      if (error is! ToolExit) {
        _logger.printError('$error\n$st');
      }
      await _cleanUp(null);
      rethrow;
    } finally {
      _processingUserRequest = false;
      if (_reportReady) {
        _logger.printStatus('ready');
      }
    }
  }

  Future<void> _handleSignal(io.ProcessSignal signal) async {
    if (_processingUserRequest) {
      _logger.printTrace('Ignoring signal: "$signal" because we are busy.');
      return;
    }
    _processingUserRequest = true;

    final bool fullRestart = signal == io.ProcessSignal.sigusr2;

    try {
      await residentRunner.restart(fullRestart: fullRestart);
    } finally {
      _processingUserRequest = false;
    }
  }

  Future<void> _cleanUp(io.ProcessSignal? signal) async {
    _terminal.singleCharMode = false;
    await subscription?.cancel();
    await residentRunner.cleanupAfterSignal();
  }
}

class DebugConnectionInfo {
  DebugConnectionInfo({ this.httpUri, this.wsUri, this.baseUri });

  final Uri? httpUri;
  final Uri? wsUri;
  final String? baseUri;
}

String nextPlatform(String currentPlatform) {
  const List<String> platforms = <String>[
    'android',
    'iOS',
    'windows',
    'macOS',
    'linux',
    'fuchsia',
  ];
  final int index = platforms.indexOf(currentPlatform);
  assert(index >= 0, 'unknown platform "$currentPlatform"');
  return platforms[(index + 1) % platforms.length];
}

abstract class DevtoolsLauncher {
  static DevtoolsLauncher? get instance => context.get<DevtoolsLauncher>();

  Future<DevToolsServerAddress?> serve();

  Future<void> launch(Uri vmServiceUri, {List<String>? additionalArguments});

  Future<void> close();

  Future<void>? processStart;

  Future<void> get ready => _readyCompleter.future;
  Completer<void> _readyCompleter = Completer<void>();

  Uri? get devToolsUrl => _devToolsUrl;
  Uri? _devToolsUrl;
  set devToolsUrl(Uri? value) {
    assert((_devToolsUrl == null) != (value == null));
    _devToolsUrl = value;
    if (_devToolsUrl != null) {
      _readyCompleter.complete();
    } else {
      _readyCompleter = Completer<void>();
    }
  }

  DevToolsServerAddress? get activeDevToolsServer {
    if (_devToolsUrl == null) {
      return null;
    }
    return DevToolsServerAddress(devToolsUrl!.host, devToolsUrl!.port);
  }
}

class DevToolsServerAddress {
  DevToolsServerAddress(this.host, this.port);

  final String host;
  final int port;

  Uri? get uri {
    return Uri(scheme: 'http', host: host, port: port);
  }
}