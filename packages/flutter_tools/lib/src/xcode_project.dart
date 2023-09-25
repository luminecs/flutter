import 'base/error_handling_io.dart';
import 'base/file_system.dart';
import 'base/utils.dart';
import 'build_info.dart';
import 'bundle.dart' as bundle;
import 'convert.dart';
import 'flutter_plugins.dart';
import 'globals.dart' as globals;
import 'ios/code_signing.dart';
import 'ios/plist_parser.dart';
import 'ios/xcode_build_settings.dart' as xcode;
import 'ios/xcodeproj.dart';
import 'platform_plugins.dart';
import 'project.dart';
import 'template.dart';

abstract class XcodeBasedProject extends FlutterProjectPlatform  {
  static const String _defaultHostAppName = 'Runner';

  Directory? get xcodeWorkspace {
    if (!hostAppRoot.existsSync()) {
      return null;
    }
    return _xcodeDirectoryWithExtension('.xcworkspace');
  }

  late final String hostAppProjectName = () {
    if (!hostAppRoot.existsSync()) {
      return _defaultHostAppName;
    }
    final Directory? xcodeProjectDirectory = _xcodeDirectoryWithExtension('.xcodeproj');
    return xcodeProjectDirectory != null
        ? xcodeProjectDirectory.fileSystem.path.basenameWithoutExtension(xcodeProjectDirectory.path)
        : _defaultHostAppName;
  }();

  Directory? _xcodeDirectoryWithExtension(String extension) {
    final List<FileSystemEntity> contents = hostAppRoot.listSync();
    for (final FileSystemEntity entity in contents) {
      if (globals.fs.path.extension(entity.path) == extension && !globals.fs.path.basename(entity.path).startsWith('.')) {
        return hostAppRoot.childDirectory(entity.basename);
      }
    }
    return null;
  }

  FlutterProject get parent;

  Directory get hostAppRoot;

  File get defaultHostInfoPlist => hostAppRoot.childDirectory(_defaultHostAppName).childFile('Info.plist');

  Directory get xcodeProject => hostAppRoot.childDirectory('$hostAppProjectName.xcodeproj');

  File get xcodeProjectInfoFile => xcodeProject.childFile('project.pbxproj');

  File get xcodeProjectSchemeFile =>
      xcodeProject.childDirectory('xcshareddata').childDirectory('xcschemes').childFile('Runner.xcscheme');

  File get xcodeProjectWorkspaceData =>
      xcodeProject
          .childDirectory('project.xcworkspace')
          .childFile('contents.xcworkspacedata');

  Directory? get xcodeWorkspaceSharedData => xcodeWorkspace?.childDirectory('xcshareddata');

  File? get xcodeWorkspaceSharedSettings => xcodeWorkspaceSharedData?.childFile('WorkspaceSettings.xcsettings');

  File get generatedXcodePropertiesFile;

  File xcodeConfigFor(String mode);

  File get generatedEnvironmentVariableExportScript;

  File get podfile => hostAppRoot.childFile('Podfile');

  File get podfileLock => hostAppRoot.childFile('Podfile.lock');

  File get podManifestLock => hostAppRoot.childDirectory('Pods').childFile('Manifest.lock');

  File get podRunnerFrameworksScript => podRunnerTargetSupportFiles
      .childFile('Pods-Runner-frameworks.sh');

  Directory get podRunnerTargetSupportFiles => hostAppRoot
      .childDirectory('Pods')
      .childDirectory('Target Support Files')
      .childDirectory('Pods-Runner');
}

class IosProject extends XcodeBasedProject {
  IosProject.fromFlutter(this.parent);

  @override
  final FlutterProject parent;

  @override
  String get pluginConfigKey => IOSPlugin.kConfigKey;

  // build setting keys
  static const String kProductBundleIdKey = 'PRODUCT_BUNDLE_IDENTIFIER';
  static const String kTeamIdKey = 'DEVELOPMENT_TEAM';
  static const String kEntitlementFilePathKey = 'CODE_SIGN_ENTITLEMENTS';
  static const String kHostAppBundleNameKey = 'FULL_PRODUCT_NAME';

  static final RegExp _productBundleIdPattern = RegExp('^\\s*$kProductBundleIdKey\\s*=\\s*(["\']?)(.*?)\\1;\\s*\$');
  static const String _kProductBundleIdVariable = '\$($kProductBundleIdKey)';

  static final RegExp _associatedDomainPattern = RegExp(r'^applinks:(.*)');

  Directory get ephemeralModuleDirectory => parent.directory.childDirectory('.ios');
  Directory get _editableDirectory => parent.directory.childDirectory('ios');

  @override
  Directory get hostAppRoot {
    if (!isModule || _editableDirectory.existsSync()) {
      return _editableDirectory;
    }
    return ephemeralModuleDirectory;
  }

  Directory get _flutterLibRoot => isModule ? ephemeralModuleDirectory : _editableDirectory;

  bool get isModule => parent.isModule;

  bool get exists => hostAppRoot.existsSync();

  Directory get ephemeralDirectory => _flutterLibRoot.childDirectory('Flutter').childDirectory('ephemeral');

  @override
  File xcodeConfigFor(String mode) => _flutterLibRoot.childDirectory('Flutter').childFile('$mode.xcconfig');

  @override
  File get generatedEnvironmentVariableExportScript => _flutterLibRoot.childDirectory('Flutter').childFile('flutter_export_environment.sh');

  File get appFrameworkInfoPlist => _flutterLibRoot.childDirectory('Flutter').childFile('AppFrameworkInfo.plist');

  File get infoPlist => _editableDirectory.childDirectory('Runner').childFile('Info.plist');

  Directory get symlinks => _flutterLibRoot.childDirectory('.symlinks');

  bool get isSwift {
    final File appDelegateSwift = _editableDirectory.childDirectory('Runner').childFile('AppDelegate.swift');
    return appDelegateSwift.existsSync();
  }

  Future<bool> pluginsSupportArmSimulator() async {
    final Directory podXcodeProject = hostAppRoot
        .childDirectory('Pods')
        .childDirectory('Pods.xcodeproj');
    if (!podXcodeProject.existsSync()) {
      // No plugins.
      return true;
    }

    final XcodeProjectInterpreter? xcodeProjectInterpreter = globals.xcodeProjectInterpreter;
    if (xcodeProjectInterpreter == null) {
      // Xcode isn't installed, don't try to check.
      return false;
    }
    final String? buildSettings = await xcodeProjectInterpreter.pluginsBuildSettingsOutput(podXcodeProject);

    // See if any plugins or their dependencies exclude arm64 simulators
    // as a valid architecture, usually because a binary is missing that slice.
    // Example: EXCLUDED_ARCHS = arm64 i386
    // NOT: EXCLUDED_ARCHS = i386
    return buildSettings != null && !buildSettings.contains(RegExp('EXCLUDED_ARCHS.*arm64'));
  }

  @override
  bool existsSync()  {
    return parent.isModule || _editableDirectory.existsSync();
  }

  Future<String> outputsUniversalLinkSettings({
    required String configuration,
    required String target,
  }) async {
    final XcodeProjectBuildContext context = XcodeProjectBuildContext(
      configuration: configuration,
      target: target,
    );
    final File file = await parent.buildDirectory
        .childDirectory('deeplink_data')
        .childFile('universal-link-settings-$configuration-$target.json')
        .create(recursive: true);

    await file.writeAsString(jsonEncode(<String, Object?>{
      'bundleIdentifier': await _productBundleIdentifierWithBuildContext(context),
      'teamIdentifier': await _getTeamIdentifier(context),
      'associatedDomains': await _getAssociatedDomains(context),
    }));
    return file.absolute.path;
  }

  Future<String?> productBundleIdentifier(BuildInfo? buildInfo) async {
    if (!existsSync()) {
      return null;
    }

    XcodeProjectBuildContext? buildContext;
    final XcodeProjectInfo? info = await projectInfo();
    if (info != null) {
      final String? scheme = info.schemeFor(buildInfo);
      if (scheme == null) {
        info.reportFlavorNotFoundAndExit();
      }
      final String? configuration = info.buildConfigurationFor(
        buildInfo,
        scheme,
      );
      buildContext = XcodeProjectBuildContext(
        configuration: configuration,
        scheme: scheme,
      );
    }
    return _productBundleIdentifierWithBuildContext(buildContext);
  }

  Future<String?> _productBundleIdentifierWithBuildContext(XcodeProjectBuildContext? buildContext) async {
    if (!existsSync()) {
      return null;
    }
    if (_productBundleIdentifiers.containsKey(buildContext)) {
      return _productBundleIdentifiers[buildContext];
    }
    return _productBundleIdentifiers[buildContext] = await _parseProductBundleIdentifier(buildContext);
  }

  final Map<XcodeProjectBuildContext?, String?> _productBundleIdentifiers = <XcodeProjectBuildContext?, String?>{};


  Future<String?> _parseProductBundleIdentifier(XcodeProjectBuildContext? buildContext) async {
    String? fromPlist;
    final File defaultInfoPlist = defaultHostInfoPlist;
    // Users can change the location of the Info.plist.
    // Try parsing the default, first.
    if (defaultInfoPlist.existsSync()) {
      try {
        fromPlist = globals.plistParser.getValueFromFile<String>(
          defaultHostInfoPlist.path,
          PlistParser.kCFBundleIdentifierKey,
        );
      } on FileNotFoundException {
        // iOS tooling not found; likely not running OSX; let [fromPlist] be null
      }
      if (fromPlist != null && !fromPlist.contains(r'$')) {
        // Info.plist has no build variables in product bundle ID.
        return fromPlist;
      }
    }
    if (buildContext == null) {
      // Getting build settings to evaluate info.Plist requires a context.
      return null;
    }

    final Map<String, String>? allBuildSettings = await _buildSettingsForXcodeProjectBuildContext(buildContext);
    if (allBuildSettings != null) {
      if (fromPlist != null) {
        // Perform variable substitution using build settings.
        return substituteXcodeVariables(fromPlist, allBuildSettings);
      }
      return allBuildSettings[kProductBundleIdKey];
    }

    // On non-macOS platforms, parse the first PRODUCT_BUNDLE_IDENTIFIER from
    // the project file. This can return the wrong bundle identifier if additional
    // bundles have been added to the project and are found first, like frameworks
    // or companion watchOS projects. However, on non-macOS platforms this is
    // only used for display purposes and to regenerate organization names, so
    // best-effort is probably fine.
    final String? fromPbxproj = firstMatchInFile(xcodeProjectInfoFile, _productBundleIdPattern)?.group(2);
    if (fromPbxproj != null && (fromPlist == null || fromPlist == _kProductBundleIdVariable)) {
      return fromPbxproj;
    }
    return null;
  }

  Future<String?> _getTeamIdentifier(XcodeProjectBuildContext buildContext) async {
    final Map<String, String>? buildSettings = await _buildSettingsForXcodeProjectBuildContext(buildContext);
    if (buildSettings != null) {
      return buildSettings[kTeamIdKey];
    }
    return null;
  }

  Future<List<String>> _getAssociatedDomains(XcodeProjectBuildContext buildContext) async {
    final Map<String, String>? buildSettings = await _buildSettingsForXcodeProjectBuildContext(buildContext);
    if (buildSettings != null) {
      final String? entitlementPath = buildSettings[kEntitlementFilePathKey];
      if (entitlementPath != null) {
        final File entitlement = hostAppRoot.childFile(entitlementPath);
        if (entitlement.existsSync()) {
          final List<String>? domains = globals.plistParser.getValueFromFile<List<Object>>(
            entitlement.path,
            PlistParser.kAssociatedDomainsKey,
          )?.cast<String>();

          if (domains != null) {
            final List<String> result = <String>[];
            for (final String domain in domains) {
              final RegExpMatch? match = _associatedDomainPattern.firstMatch(domain);
              if (match != null) {
                result.add(match.group(1)!);
              }
            }
            return result;
          }
        }
      }
    }
    return const <String>[];
  }

  Future<String?> hostAppBundleName(BuildInfo? buildInfo) async {
    if (!existsSync()) {
      return null;
    }
    return _hostAppBundleName ??= await _parseHostAppBundleName(buildInfo);
  }
  String? _hostAppBundleName;

  Future<String> _parseHostAppBundleName(BuildInfo? buildInfo) async {
    // The product name and bundle name are derived from the display name, which the user
    // is instructed to change in Xcode as part of deploying to the App Store.
    // https://flutter.dev/docs/deployment/ios#review-xcode-project-settings
    // The only source of truth for the name is Xcode's interpretation of the build settings.
    String? productName;
    if (globals.xcodeProjectInterpreter?.isInstalled ?? false) {
      final Map<String, String>? xcodeBuildSettings = await buildSettingsForBuildInfo(buildInfo);
      if (xcodeBuildSettings != null) {
        productName = xcodeBuildSettings[kHostAppBundleNameKey];
      }
    }
    if (productName == null) {
      globals.printTrace('$kHostAppBundleNameKey not present, defaulting to $hostAppProjectName');
    }
    return productName ?? '${XcodeBasedProject._defaultHostAppName}.app';
  }

  Future<Map<String, String>?> buildSettingsForBuildInfo(
    BuildInfo? buildInfo, {
    String? scheme,
    String? configuration,
    String? target,
    EnvironmentType environmentType = EnvironmentType.physical,
    String? deviceId,
    bool isWatch = false,
  }) async {
    if (!existsSync()) {
      return null;
    }
    final XcodeProjectInfo? info = await projectInfo();
    if (info == null) {
      return null;
    }

    scheme ??= info.schemeFor(buildInfo);
    if (scheme == null) {
      info.reportFlavorNotFoundAndExit();
    }

    configuration ??= (await projectInfo())?.buildConfigurationFor(
      buildInfo,
      scheme,
    );
    return _buildSettingsForXcodeProjectBuildContext(
      XcodeProjectBuildContext(
        environmentType: environmentType,
        scheme: scheme,
        configuration: configuration,
        target: target,
        deviceId: deviceId,
        isWatch: isWatch,
      ),
    );
  }

  Future<Map<String, String>?> _buildSettingsForXcodeProjectBuildContext(XcodeProjectBuildContext buildContext) async {
    if (!existsSync()) {
      return null;
    }
    final Map<String, String>? currentBuildSettings = _buildSettingsByBuildContext[buildContext];
    if (currentBuildSettings == null) {
      final Map<String, String>? calculatedBuildSettings = await _xcodeProjectBuildSettings(buildContext);
      if (calculatedBuildSettings != null) {
        _buildSettingsByBuildContext[buildContext] = calculatedBuildSettings;
      }
    }
    return _buildSettingsByBuildContext[buildContext];
  }

  final Map<XcodeProjectBuildContext, Map<String, String>> _buildSettingsByBuildContext = <XcodeProjectBuildContext, Map<String, String>>{};

  Future<XcodeProjectInfo?> projectInfo() async {
    final XcodeProjectInterpreter? xcodeProjectInterpreter = globals.xcodeProjectInterpreter;
    if (!xcodeProject.existsSync() || xcodeProjectInterpreter == null || !xcodeProjectInterpreter.isInstalled) {
      return null;
    }
    return _projectInfo ??= await xcodeProjectInterpreter.getInfo(hostAppRoot.path);
  }
  XcodeProjectInfo? _projectInfo;

  Future<Map<String, String>?> _xcodeProjectBuildSettings(XcodeProjectBuildContext buildContext) async {
    final XcodeProjectInterpreter? xcodeProjectInterpreter = globals.xcodeProjectInterpreter;
    if (xcodeProjectInterpreter == null || !xcodeProjectInterpreter.isInstalled) {
      return null;
    }

    final Map<String, String> buildSettings = await xcodeProjectInterpreter.getBuildSettings(
      xcodeProject.path,
      buildContext: buildContext,
    );
    if (buildSettings.isNotEmpty) {
      // No timeouts, flakes, or errors.
      return buildSettings;
    }
    return null;
  }

  Future<void> ensureReadyForPlatformSpecificTooling() async {
    await _regenerateFromTemplateIfNeeded();
    if (!_flutterLibRoot.existsSync()) {
      return;
    }
    await _updateGeneratedXcodeConfigIfNeeded();
  }

  Future<bool> containsWatchCompanion({
    required XcodeProjectInfo projectInfo,
    required BuildInfo buildInfo,
    String? deviceId,
  }) async {
    final String? bundleIdentifier = await productBundleIdentifier(buildInfo);
    // A bundle identifier is required for a companion app.
    if (bundleIdentifier == null) {
      return false;
    }
    for (final String target in projectInfo.targets) {
      // Create Info.plist file of the target.
      final File infoFile = hostAppRoot.childDirectory(target).childFile('Info.plist');
      // In older versions of Xcode, if the target was a watchOS companion app,
      // the Info.plist file of the target contained the key WKCompanionAppBundleIdentifier.
      if (infoFile.existsSync()) {
        final String? fromPlist = globals.plistParser.getValueFromFile<String>(infoFile.path, 'WKCompanionAppBundleIdentifier');
        if (bundleIdentifier == fromPlist) {
          return true;
        }

        // The key WKCompanionAppBundleIdentifier might contain an xcode variable
        // that needs to be substituted before comparing it with bundle id
        if (fromPlist != null && fromPlist.contains(r'$')) {
          final Map<String, String>? allBuildSettings = await buildSettingsForBuildInfo(buildInfo, deviceId: deviceId);
          if (allBuildSettings != null) {
            final String substitutedVariable = substituteXcodeVariables(fromPlist, allBuildSettings);
            if (substitutedVariable == bundleIdentifier) {
              return true;
            }
          }
        }
      }
    }

    // If key not found in Info.plist above, do more expensive check of build settings.
    // In newer versions of Xcode, the build settings of the watchOS companion
    // app's scheme should contain the key INFOPLIST_KEY_WKCompanionAppBundleIdentifier.
    final bool watchIdentifierFound = xcodeProjectInfoFile.readAsStringSync().contains('WKCompanionAppBundleIdentifier');
    if (!watchIdentifierFound) {
      return false;
    }

    final String? defaultScheme = projectInfo.schemeFor(buildInfo);
    if (defaultScheme == null) {
      projectInfo.reportFlavorNotFoundAndExit();
    }
    for (final String scheme in projectInfo.schemes) {
      // the default scheme should not be a watch scheme, so skip it
      if (scheme == defaultScheme) {
        continue;
      }
      final Map<String, String>? allBuildSettings = await buildSettingsForBuildInfo(
        buildInfo,
        deviceId: deviceId,
        scheme: scheme,
        isWatch: true,
      );
      if (allBuildSettings != null) {
        final String? fromBuild = allBuildSettings['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'];
        if (bundleIdentifier == fromBuild) {
          return true;
        }
        if (fromBuild != null && fromBuild.contains(r'$')) {
          final String substitutedVariable = substituteXcodeVariables(fromBuild, allBuildSettings);
          if (substitutedVariable == bundleIdentifier) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> _updateGeneratedXcodeConfigIfNeeded() async {
    if (globals.cache.isOlderThanToolsStamp(generatedXcodePropertiesFile)) {
      await xcode.updateGeneratedXcodeProperties(
        project: parent,
        buildInfo: BuildInfo.debug,
        targetOverride: bundle.defaultMainPath,
      );
    }
  }

  Future<void> _regenerateFromTemplateIfNeeded() async {
    if (!isModule) {
      return;
    }
    final bool pubspecChanged = globals.fsUtils.isOlderThanReference(
      entity: ephemeralModuleDirectory,
      referenceFile: parent.pubspecFile,
    );
    final bool toolingChanged = globals.cache.isOlderThanToolsStamp(ephemeralModuleDirectory);
    if (!pubspecChanged && !toolingChanged) {
      return;
    }

    ErrorHandlingFileSystem.deleteIfExists(ephemeralModuleDirectory, recursive: true);
    await _overwriteFromTemplate(
      globals.fs.path.join('module', 'ios', 'library'),
      ephemeralModuleDirectory,
    );
    // Add ephemeral host app, if a editable host app does not already exist.
    if (!_editableDirectory.existsSync()) {
      await _overwriteFromTemplate(
        globals.fs.path.join('module', 'ios', 'host_app_ephemeral'),
        ephemeralModuleDirectory,
      );
      if (hasPlugins(parent)) {
        await _overwriteFromTemplate(
          globals.fs.path.join('module', 'ios', 'host_app_ephemeral_cocoapods'),
          ephemeralModuleDirectory,
        );
      }
    }
  }

  @override
  File get generatedXcodePropertiesFile => _flutterLibRoot
    .childDirectory('Flutter')
    .childFile('Generated.xcconfig');

  Directory get deprecatedCompiledDartFramework => _flutterLibRoot
      .childDirectory('Flutter')
      .childDirectory('App.framework');

  Directory get deprecatedProjectFlutterFramework => _flutterLibRoot
      .childDirectory('Flutter')
      .childDirectory('Flutter.framework');

  File get flutterPodspec => _flutterLibRoot
      .childDirectory('Flutter')
      .childFile('Flutter.podspec');

  Directory get pluginRegistrantHost {
    return isModule
        ? _flutterLibRoot
            .childDirectory('Flutter')
            .childDirectory('FlutterPluginRegistrant')
        : hostAppRoot.childDirectory(XcodeBasedProject._defaultHostAppName);
  }

  File get pluginRegistrantHeader {
    final Directory registryDirectory = isModule ? pluginRegistrantHost.childDirectory('Classes') : pluginRegistrantHost;
    return registryDirectory.childFile('GeneratedPluginRegistrant.h');
  }

  File get pluginRegistrantImplementation {
    final Directory registryDirectory = isModule ? pluginRegistrantHost.childDirectory('Classes') : pluginRegistrantHost;
    return registryDirectory.childFile('GeneratedPluginRegistrant.m');
  }

  Future<void> _overwriteFromTemplate(String path, Directory target) async {
    final Template template = await Template.fromName(
      path,
      fileSystem: globals.fs,
      templateManifest: null,
      logger: globals.logger,
      templateRenderer: globals.templateRenderer,
    );
    final String iosBundleIdentifier = parent.manifest.iosBundleIdentifier ?? 'com.example.${parent.manifest.appName}';

    final String? iosDevelopmentTeam = await getCodeSigningIdentityDevelopmentTeam(
      processManager: globals.processManager,
      platform: globals.platform,
      logger: globals.logger,
      config: globals.config,
      terminal: globals.terminal,
    );

    final String projectName = parent.manifest.appName;

    // The dart project_name is in snake_case, this variable is the Title Case of the Project Name.
    final String titleCaseProjectName = snakeCaseToTitleCase(projectName);

    template.render(
      target,
      <String, Object>{
        'ios': true,
        'projectName': projectName,
        'titleCaseProjectName': titleCaseProjectName,
        'iosIdentifier': iosBundleIdentifier,
        'hasIosDevelopmentTeam': iosDevelopmentTeam != null && iosDevelopmentTeam.isNotEmpty,
        'iosDevelopmentTeam': iosDevelopmentTeam ?? '',
      },
      printStatusWhenWriting: false,
    );
  }
}

class MacOSProject extends XcodeBasedProject {
  MacOSProject.fromFlutter(this.parent);

  @override
  final FlutterProject parent;

  @override
  String get pluginConfigKey => MacOSPlugin.kConfigKey;

  @override
  bool existsSync() => hostAppRoot.existsSync();

  @override
  Directory get hostAppRoot => parent.directory.childDirectory('macos');

  Directory get managedDirectory => hostAppRoot.childDirectory('Flutter');

  Directory get ephemeralDirectory => managedDirectory.childDirectory('ephemeral');

  File get inputFileList => ephemeralDirectory.childFile('FlutterInputs.xcfilelist');

  File get outputFileList => ephemeralDirectory.childFile('FlutterOutputs.xcfilelist');

  @override
  File get generatedXcodePropertiesFile => ephemeralDirectory.childFile('Flutter-Generated.xcconfig');

  File get pluginRegistrantImplementation => managedDirectory.childFile('GeneratedPluginRegistrant.swift');

  @override
  File xcodeConfigFor(String mode) => managedDirectory.childFile('Flutter-$mode.xcconfig');

  @override
  File get generatedEnvironmentVariableExportScript => ephemeralDirectory.childFile('flutter_export_environment.sh');

  File get nameFile => ephemeralDirectory.childFile('.app_filename');

  Future<void> ensureReadyForPlatformSpecificTooling() async {
    // TODO(stuartmorgan): Add create-from-template logic here.
    await _updateGeneratedXcodeConfigIfNeeded();
  }

  Future<void> _updateGeneratedXcodeConfigIfNeeded() async {
    if (globals.cache.isOlderThanToolsStamp(generatedXcodePropertiesFile)) {
      await xcode.updateGeneratedXcodeProperties(
        project: parent,
        buildInfo: BuildInfo.debug,
        useMacOSConfig: true,
      );
    }
  }
}