import 'package:meta/meta.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import '../src/convert.dart';
import 'android/android_builder.dart';
import 'android/gradle_utils.dart' as gradle;
import 'base/common.dart';
import 'base/error_handling_io.dart';
import 'base/file_system.dart';
import 'base/logger.dart';
import 'base/utils.dart';
import 'base/version.dart';
import 'bundle.dart' as bundle;
import 'cmake_project.dart';
import 'features.dart';
import 'flutter_manifest.dart';
import 'flutter_plugins.dart';
import 'globals.dart' as globals;
import 'platform_plugins.dart';
import 'project_validator_result.dart';
import 'reporting/reporting.dart';
import 'template.dart';
import 'xcode_project.dart';

export 'cmake_project.dart';
export 'xcode_project.dart';

enum SupportedPlatform {
  android,
  ios,
  linux,
  macos,
  web,
  windows,
  fuchsia,
  root, // Special platform to represent the root project directory
}

class FlutterProjectFactory {
  FlutterProjectFactory({
    required Logger logger,
    required FileSystem fileSystem,
  })  : _logger = logger,
        _fileSystem = fileSystem;

  final Logger _logger;
  final FileSystem _fileSystem;

  @visibleForTesting
  final Map<String, FlutterProject> projects = <String, FlutterProject>{};

  FlutterProject fromDirectory(Directory directory) {
    return projects.putIfAbsent(directory.path, () {
      final FlutterManifest manifest = FlutterProject._readManifest(
        directory.childFile(bundle.defaultManifestPath).path,
        logger: _logger,
        fileSystem: _fileSystem,
      );
      final FlutterManifest exampleManifest = FlutterProject._readManifest(
        FlutterProject._exampleDirectory(directory)
            .childFile(bundle.defaultManifestPath)
            .path,
        logger: _logger,
        fileSystem: _fileSystem,
      );
      return FlutterProject(directory, manifest, exampleManifest);
    });
  }
}

class FlutterProject {
  @visibleForTesting
  FlutterProject(this.directory, this.manifest, this._exampleManifest);

  static FlutterProject fromDirectory(Directory directory) =>
      globals.projectFactory.fromDirectory(directory);

  static FlutterProject current() =>
      globals.projectFactory.fromDirectory(globals.fs.currentDirectory);

  @visibleForTesting
  static FlutterProject fromDirectoryTest(Directory directory,
      [Logger? logger]) {
    final FileSystem fileSystem = directory.fileSystem;
    logger ??= BufferLogger.test();
    final FlutterManifest manifest = FlutterProject._readManifest(
      directory.childFile(bundle.defaultManifestPath).path,
      logger: logger,
      fileSystem: fileSystem,
    );
    final FlutterManifest exampleManifest = FlutterProject._readManifest(
      FlutterProject._exampleDirectory(directory)
          .childFile(bundle.defaultManifestPath)
          .path,
      logger: logger,
      fileSystem: fileSystem,
    );
    return FlutterProject(directory, manifest, exampleManifest);
  }

  final Directory directory;

  Directory get buildDirectory => directory.childDirectory('build');

  final FlutterManifest manifest;

  final FlutterManifest _exampleManifest;

  Future<Set<String>> get organizationNames async {
    final List<String> candidates = <String>[];

    if (ios.existsSync()) {
      // Don't require iOS build info, this method is only
      // used during create as best-effort, use the
      // default target bundle identifier.
      try {
        final String? bundleIdentifier =
            await ios.productBundleIdentifier(null);
        if (bundleIdentifier != null) {
          candidates.add(bundleIdentifier);
        }
      } on ToolExit {
        // It's possible that while parsing the build info for the ios project
        // that the bundleIdentifier can't be resolve. However, we would like
        // skip parsing that id in favor of searching in other place. We can
        // consider a tool exit in this case to be non fatal for the program.
      }
    }
    if (android.existsSync()) {
      final String? applicationId = android.applicationId;
      final String? group = android.group;
      candidates.addAll(<String>[
        if (applicationId != null) applicationId,
        if (group != null) group,
      ]);
    }
    if (example.android.existsSync()) {
      final String? applicationId = example.android.applicationId;
      if (applicationId != null) {
        candidates.add(applicationId);
      }
    }
    if (example.ios.existsSync()) {
      final String? bundleIdentifier =
          await example.ios.productBundleIdentifier(null);
      if (bundleIdentifier != null) {
        candidates.add(bundleIdentifier);
      }
    }
    return Set<String>.of(candidates
        .map<String?>(_organizationNameFromPackageName)
        .whereType<String>());
  }

  String? _organizationNameFromPackageName(String packageName) {
    if (0 <= packageName.lastIndexOf('.')) {
      return packageName.substring(0, packageName.lastIndexOf('.'));
    }
    return null;
  }

  late final IosProject ios = IosProject.fromFlutter(this);

  late final AndroidProject android = AndroidProject._(this);

  late final WebProject web = WebProject._(this);

  late final MacOSProject macos = MacOSProject.fromFlutter(this);

  late final LinuxProject linux = LinuxProject.fromFlutter(this);

  late final WindowsProject windows = WindowsProject.fromFlutter(this);

  late final FuchsiaProject fuchsia = FuchsiaProject._(this);

  File get pubspecFile => directory.childFile('pubspec.yaml');

  File get packagesFile => directory.childFile('.packages');

  File get packageConfigFile =>
      directory.childDirectory('.dart_tool').childFile('package_config.json');

  File get metadataFile => directory.childFile('.metadata');

  File get flutterPluginsFile => directory.childFile('.flutter-plugins');

  File get flutterPluginsDependenciesFile =>
      directory.childFile('.flutter-plugins-dependencies');

  Directory get dartTool => directory.childDirectory('.dart_tool');

  Directory get generated => directory.absolute
      .childDirectory('.dart_tool')
      .childDirectory('build')
      .childDirectory('generated')
      .childDirectory(manifest.appName);

  File get dartPluginRegistrant => dartTool
      .childDirectory('flutter_build')
      .childFile('dart_plugin_registrant.dart');

  FlutterProject get example => FlutterProject(
        _exampleDirectory(directory),
        _exampleManifest,
        FlutterManifest.empty(logger: globals.logger),
      );

  bool get isModule => manifest.isModule;

  bool get isPlugin => manifest.isPlugin;

  bool get usesAndroidX => manifest.usesAndroidX;

  bool get hasExampleApp => _exampleDirectory(directory).existsSync();

  List<SupportedPlatform> getSupportedPlatforms({bool includeRoot = false}) {
    final List<SupportedPlatform> platforms = includeRoot
        ? <SupportedPlatform>[SupportedPlatform.root]
        : <SupportedPlatform>[];
    if (android.existsSync()) {
      platforms.add(SupportedPlatform.android);
    }
    if (ios.exists) {
      platforms.add(SupportedPlatform.ios);
    }
    if (web.existsSync()) {
      platforms.add(SupportedPlatform.web);
    }
    if (macos.existsSync()) {
      platforms.add(SupportedPlatform.macos);
    }
    if (linux.existsSync()) {
      platforms.add(SupportedPlatform.linux);
    }
    if (windows.existsSync()) {
      platforms.add(SupportedPlatform.windows);
    }
    if (fuchsia.existsSync()) {
      platforms.add(SupportedPlatform.fuchsia);
    }
    return platforms;
  }

  static Directory _exampleDirectory(Directory directory) =>
      directory.childDirectory('example');

  static FlutterManifest _readManifest(
    String path, {
    required Logger logger,
    required FileSystem fileSystem,
  }) {
    FlutterManifest? manifest;
    try {
      manifest = FlutterManifest.createFromPath(
        path,
        logger: logger,
        fileSystem: fileSystem,
      );
    } on YamlException catch (e) {
      logger.printStatus('Error detected in pubspec.yaml:', emphasis: true);
      logger.printError('$e');
    } on FormatException catch (e) {
      logger.printError('Error detected while parsing pubspec.yaml:',
          emphasis: true);
      logger.printError('$e');
    } on FileSystemException catch (e) {
      logger.printError('Error detected while reading pubspec.yaml:',
          emphasis: true);
      logger.printError('$e');
    }
    if (manifest == null) {
      throwToolExit('Please correct the pubspec.yaml file at $path');
    }
    return manifest;
  }

  Future<void> regeneratePlatformSpecificTooling(
      {DeprecationBehavior deprecationBehavior =
          DeprecationBehavior.none}) async {
    return ensureReadyForPlatformSpecificTooling(
      androidPlatform: android.existsSync(),
      iosPlatform: ios.existsSync(),
      // TODO(stuartmorgan): Revisit the conditions here once the plans for handling
      // desktop in existing projects are in place.
      linuxPlatform: featureFlags.isLinuxEnabled && linux.existsSync(),
      macOSPlatform: featureFlags.isMacOSEnabled && macos.existsSync(),
      windowsPlatform: featureFlags.isWindowsEnabled && windows.existsSync(),
      webPlatform: featureFlags.isWebEnabled && web.existsSync(),
      deprecationBehavior: deprecationBehavior,
    );
  }

  Future<void> ensureReadyForPlatformSpecificTooling({
    bool androidPlatform = false,
    bool iosPlatform = false,
    bool linuxPlatform = false,
    bool macOSPlatform = false,
    bool windowsPlatform = false,
    bool webPlatform = false,
    DeprecationBehavior deprecationBehavior = DeprecationBehavior.none,
  }) async {
    if (!directory.existsSync() || isPlugin) {
      return;
    }
    await refreshPluginsList(this,
        iosPlatform: iosPlatform, macOSPlatform: macOSPlatform);
    if (androidPlatform) {
      await android.ensureReadyForPlatformSpecificTooling(
          deprecationBehavior: deprecationBehavior);
    }
    if (iosPlatform) {
      await ios.ensureReadyForPlatformSpecificTooling();
    }
    if (linuxPlatform) {
      await linux.ensureReadyForPlatformSpecificTooling();
    }
    if (macOSPlatform) {
      await macos.ensureReadyForPlatformSpecificTooling();
    }
    if (windowsPlatform) {
      await windows.ensureReadyForPlatformSpecificTooling();
    }
    if (webPlatform) {
      await web.ensureReadyForPlatformSpecificTooling();
    }
    await injectPlugins(
      this,
      androidPlatform: androidPlatform,
      iosPlatform: iosPlatform,
      linuxPlatform: linuxPlatform,
      macOSPlatform: macOSPlatform,
      windowsPlatform: windowsPlatform,
    );
  }

  void checkForDeprecation(
      {DeprecationBehavior deprecationBehavior = DeprecationBehavior.none}) {
    if (android.existsSync() && pubspecFile.existsSync()) {
      android.checkForDeprecation(deprecationBehavior: deprecationBehavior);
    }
  }

  String getVersionInfo() {
    final String? buildName = manifest.buildName;
    final String? buildNumber = manifest.buildNumber;
    final Map<String, String> versionFileJson = <String, String>{
      'app_name': manifest.appName,
      if (buildName != null) 'version': buildName,
      if (buildNumber != null) 'build_number': buildNumber,
      'package_name': manifest.appName,
    };
    return jsonEncode(versionFileJson);
  }
}

abstract class FlutterProjectPlatform {
  String get pluginConfigKey;

  bool existsSync();
}

class AndroidProject extends FlutterProjectPlatform {
  AndroidProject._(this.parent);

  // User facing string when java/gradle/agp versions are compatible.
  @visibleForTesting
  static const String validJavaGradleAgpString = 'compatible java/gradle/agp';

  // User facing link that describes compatibility between gradle and
  // android gradle plugin.
  static const String gradleAgpCompatUrl =
      'https://developer.android.com/studio/releases/gradle-plugin#updating-gradle';

  // User facing link that describes compatibility between java and the first
  // version of gradle to support it.
  static const String javaGradleCompatUrl =
      'https://docs.gradle.org/current/userguide/compatibility.html#java';

  final FlutterProject parent;

  @override
  String get pluginConfigKey => AndroidPlugin.kConfigKey;

  static final RegExp _androidNamespacePattern =
      RegExp('android {[\\S\\s]+namespace[\\s]+[\'"](.+)[\'"]');
  static final RegExp _applicationIdPattern =
      RegExp('^\\s*applicationId\\s+[\'"](.*)[\'"]\\s*\$');
  static final RegExp _imperativeKotlinPluginPattern =
      RegExp('^\\s*apply plugin\\:\\s+[\'"]kotlin-android[\'"]\\s*\$');
  static final RegExp _declarativeKotlinPluginPattern =
      RegExp('^\\s*id\\s+[\'"]kotlin-android[\'"]\\s*\$');
  static final RegExp _groupPattern =
      RegExp('^\\s*group\\s+[\'"](.*)[\'"]\\s*\$');

  Directory get hostAppGradleRoot {
    if (!isModule || _editableHostAppDirectory.existsSync()) {
      return _editableHostAppDirectory;
    }
    return ephemeralDirectory;
  }

  Directory get _flutterLibGradleRoot =>
      isModule ? ephemeralDirectory : _editableHostAppDirectory;

  Directory get ephemeralDirectory =>
      parent.directory.childDirectory('.android');
  Directory get _editableHostAppDirectory =>
      parent.directory.childDirectory('android');

  bool get isModule => parent.isModule;

  bool get isPlugin => parent.isPlugin;

  bool get usesAndroidX => parent.usesAndroidX;

  late final bool isSupportedVersion = _computeSupportedVersion();

  Future<List<String>> getBuildVariants() async {
    if (!existsSync() || androidBuilder == null) {
      return const <String>[];
    }
    return androidBuilder!.getBuildVariants(project: parent);
  }

  Future<void> outputsAppLinkSettings({required String variant}) async {
    if (!existsSync() || androidBuilder == null) {
      return;
    }
    await androidBuilder!.outputsAppLinkSettings(variant, project: parent);
  }

  bool _computeSupportedVersion() {
    final FileSystem fileSystem = hostAppGradleRoot.fileSystem;
    final File plugin = hostAppGradleRoot.childFile(fileSystem.path
        .join('buildSrc', 'src', 'main', 'groovy', 'FlutterPlugin.groovy'));
    if (plugin.existsSync()) {
      return false;
    }
    try {
      for (final String line in appGradleFile.readAsLinesSync()) {
        // This syntax corresponds to applying the Flutter Gradle Plugin with a
        // script.
        // See https://docs.gradle.org/current/userguide/plugins.html#sec:script_plugins.
        final bool fileBasedApply =
            line.contains(RegExp(r'apply from: .*/flutter.gradle'));

        // This syntax corresponds to applying the Flutter Gradle Plugin using
        // the declarative "plugins {}" block after including it in the
        // pluginManagement block of the settings.gradle file.
        // See https://docs.gradle.org/current/userguide/composite_builds.html#included_plugin_builds,
        // as well as the settings.gradle and build.gradle templates.
        final bool declarativeApply =
            line.contains('dev.flutter.flutter-gradle-plugin');

        // This case allows for flutter run/build to work for modules. It does
        // not guarantee the Flutter Gradle Plugin is applied.
        final bool managed =
            line.contains("def flutterPluginVersion = 'managed'");
        if (fileBasedApply || declarativeApply || managed) {
          return true;
        }
      }
    } on FileSystemException {
      return false;
    }
    return false;
  }

  bool get isKotlin {
    final bool imperativeMatch =
        firstMatchInFile(appGradleFile, _imperativeKotlinPluginPattern) != null;
    final bool declarativeMatch =
        firstMatchInFile(appGradleFile, _declarativeKotlinPluginPattern) !=
            null;
    return imperativeMatch || declarativeMatch;
  }

  File get appGradleFile =>
      hostAppGradleRoot.childDirectory('app').childFile('build.gradle');

  File get appManifestFile {
    if (isUsingGradle) {
      return hostAppGradleRoot
          .childDirectory('app')
          .childDirectory('src')
          .childDirectory('main')
          .childFile('AndroidManifest.xml');
    }

    return hostAppGradleRoot.childFile('AndroidManifest.xml');
  }

  File get gradleAppOutV1File =>
      gradleAppOutV1Directory.childFile('app-debug.apk');

  Directory get gradleAppOutV1Directory {
    return globals.fs.directory(globals.fs.path
        .join(hostAppGradleRoot.path, 'app', 'build', 'outputs', 'apk'));
  }

  @override
  bool existsSync() {
    return parent.isModule || _editableHostAppDirectory.existsSync();
  }

  Future<ProjectValidatorResult> validateJavaAndGradleAgpVersions() async {
    // Constructing ProjectValidatorResult happens here and not in
    // flutter_tools/lib/src/project_validator.dart because of the additional
    // Complexity of variable status values and error string formatting.
    const String visibleName = 'Java/Gradle/Android Gradle Plugin';
    final CompatibilityResult validJavaGradleAgpVersions =
        await hasValidJavaGradleAgpVersions();

    return ProjectValidatorResult(
      name: visibleName,
      value: validJavaGradleAgpVersions.description,
      status: validJavaGradleAgpVersions.success
          ? StatusProjectValidator.success
          : StatusProjectValidator.error,
    );
  }

  Future<CompatibilityResult> hasValidJavaGradleAgpVersions() async {
    final String? gradleVersion = await gradle.getGradleVersion(
        hostAppGradleRoot, globals.logger, globals.processManager);
    final String? agpVersion =
        gradle.getAgpVersion(hostAppGradleRoot, globals.logger);
    final String? javaVersion = versionToParsableString(globals.java?.version);

    // Assume valid configuration.
    String description = validJavaGradleAgpString;

    final bool compatibleGradleAgp = gradle.validateGradleAndAgp(globals.logger,
        gradleV: gradleVersion, agpV: agpVersion);

    final bool compatibleJavaGradle = gradle.validateJavaAndGradle(
        globals.logger,
        javaV: javaVersion,
        gradleV: gradleVersion);

    // Begin description formatting.
    if (!compatibleGradleAgp) {
      description = '''
Incompatible Gradle/AGP versions. \n
Gradle Version: $gradleVersion, AGP Version: $agpVersion
Update Gradle to at least "${gradle.getGradleVersionFor(agpVersion!)}".\n
See the link below for more information:
$gradleAgpCompatUrl
''';
    }
    if (!compatibleJavaGradle) {
      // Should contain the agp error (if present) but not the valid String.
      description = '''
${compatibleGradleAgp ? '' : description}
Incompatible Java/Gradle versions.
Java Version: $javaVersion, Gradle Version: $gradleVersion\n
See the link below for more information:
$javaGradleCompatUrl
''';
    }
    return CompatibilityResult(
        compatibleJavaGradle && compatibleGradleAgp, description);
  }

  bool get isUsingGradle {
    return hostAppGradleRoot.childFile('build.gradle').existsSync();
  }

  String? get applicationId {
    return firstMatchInFile(appGradleFile, _applicationIdPattern)?.group(1);
  }

  String? get namespace {
    try {
      // firstMatchInFile() reads per line but `_androidNamespacePattern` matches a multiline pattern.
      return _androidNamespacePattern
          .firstMatch(appGradleFile.readAsStringSync())
          ?.group(1);
    } on FileSystemException {
      return null;
    }
  }

  String? get group {
    final File gradleFile = hostAppGradleRoot.childFile('build.gradle');
    return firstMatchInFile(gradleFile, _groupPattern)?.group(1);
  }

  Directory get buildDirectory {
    return parent.buildDirectory;
  }

  Future<void> ensureReadyForPlatformSpecificTooling(
      {DeprecationBehavior deprecationBehavior =
          DeprecationBehavior.none}) async {
    if (isModule && _shouldRegenerateFromTemplate()) {
      await _regenerateLibrary();
      // Add ephemeral host app, if an editable host app does not already exist.
      if (!_editableHostAppDirectory.existsSync()) {
        await _overwriteFromTemplate(
            globals.fs.path.join('module', 'android', 'host_app_common'),
            ephemeralDirectory);
        await _overwriteFromTemplate(
            globals.fs.path.join('module', 'android', 'host_app_ephemeral'),
            ephemeralDirectory);
      }
    }
    if (!hostAppGradleRoot.existsSync()) {
      return;
    }
    gradle.updateLocalProperties(project: parent, requireAndroidSdk: false);
  }

  bool _shouldRegenerateFromTemplate() {
    return globals.fsUtils.isOlderThanReference(
          entity: ephemeralDirectory,
          referenceFile: parent.pubspecFile,
        ) ||
        globals.cache.isOlderThanToolsStamp(ephemeralDirectory);
  }

  File get localPropertiesFile =>
      _flutterLibGradleRoot.childFile('local.properties');

  Directory get pluginRegistrantHost =>
      _flutterLibGradleRoot.childDirectory(isModule ? 'Flutter' : 'app');

  Future<void> _regenerateLibrary() async {
    ErrorHandlingFileSystem.deleteIfExists(ephemeralDirectory, recursive: true);
    await _overwriteFromTemplate(
        globals.fs.path.join(
          'module',
          'android',
          'library_new_embedding',
        ),
        ephemeralDirectory);
    await _overwriteFromTemplate(
        globals.fs.path.join('module', 'android', 'gradle'),
        ephemeralDirectory);
    globals.gradleUtils?.injectGradleWrapperIfNeeded(ephemeralDirectory);
  }

  Future<void> _overwriteFromTemplate(String path, Directory target) async {
    final Template template = await Template.fromName(
      path,
      fileSystem: globals.fs,
      templateManifest: null,
      logger: globals.logger,
      templateRenderer: globals.templateRenderer,
    );
    final String androidIdentifier = parent.manifest.androidPackage ??
        'com.example.${parent.manifest.appName}';
    template.render(
      target,
      <String, Object>{
        'android': true,
        'projectName': parent.manifest.appName,
        'androidIdentifier': androidIdentifier,
        'androidX': usesAndroidX,
        'agpVersion': gradle.templateAndroidGradlePluginVersion,
        'agpVersionForModule':
            gradle.templateAndroidGradlePluginVersionForModule,
        'kotlinVersion': gradle.templateKotlinGradlePluginVersion,
        'gradleVersion': gradle.templateDefaultGradleVersion,
        'compileSdkVersion': gradle.compileSdkVersion,
        'minSdkVersion': gradle.minSdkVersion,
        'ndkVersion': gradle.ndkVersion,
        'targetSdkVersion': gradle.targetSdkVersion,
      },
      printStatusWhenWriting: false,
    );
  }

  void checkForDeprecation(
      {DeprecationBehavior deprecationBehavior = DeprecationBehavior.none}) {
    if (deprecationBehavior == DeprecationBehavior.none) {
      return;
    }
    final AndroidEmbeddingVersionResult result = computeEmbeddingVersion();
    if (result.version != AndroidEmbeddingVersion.v1) {
      return;
    }
    globals.printStatus('''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Warning
──────────────────────────────────────────────────────────────────────────────
Your Flutter application is created using an older version of the Android
embedding. It is being deprecated in favor of Android embedding v2. To migrate
your project, follow the steps at:

https://github.com/flutter/flutter/wiki/Upgrading-pre-1.12-Android-projects

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The detected reason was:

  ${result.reason}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''');
    if (deprecationBehavior == DeprecationBehavior.ignore) {
      BuildEvent('deprecated-v1-android-embedding-ignored',
              type: 'gradle', flutterUsage: globals.flutterUsage)
          .send();
    } else {
      // DeprecationBehavior.exit
      BuildEvent('deprecated-v1-android-embedding-failed',
              type: 'gradle', flutterUsage: globals.flutterUsage)
          .send();
      throwToolExit(
        'Build failed due to use of deprecated Android v1 embedding.',
        exitCode: 1,
      );
    }
  }

  AndroidEmbeddingVersion getEmbeddingVersion() {
    return computeEmbeddingVersion().version;
  }

  AndroidEmbeddingVersionResult computeEmbeddingVersion() {
    if (isModule) {
      // A module type's Android project is used in add-to-app scenarios and
      // only supports the V2 embedding.
      return AndroidEmbeddingVersionResult(
          AndroidEmbeddingVersion.v2, 'Is add-to-app module');
    }
    if (isPlugin) {
      // Plugins do not use an appManifest, so we stop here.
      //
      // TODO(garyq): This method does not currently check for code references to
      // the v1 embedding, we should check for this once removal is further along.
      return AndroidEmbeddingVersionResult(
          AndroidEmbeddingVersion.v2, 'Is plugin');
    }
    if (!appManifestFile.existsSync()) {
      return AndroidEmbeddingVersionResult(AndroidEmbeddingVersion.v1,
          'No `${appManifestFile.absolute.path}` file');
    }
    XmlDocument document;
    try {
      document = XmlDocument.parse(appManifestFile.readAsStringSync());
    } on XmlException {
      throwToolExit('Error parsing $appManifestFile '
          'Please ensure that the android manifest is a valid XML document and try again.');
    } on FileSystemException {
      throwToolExit('Error reading $appManifestFile even though it exists. '
          'Please ensure that you have read permission to this file and try again.');
    }
    for (final XmlElement application
        in document.findAllElements('application')) {
      final String? applicationName = application.getAttribute('android:name');
      if (applicationName == 'io.flutter.app.FlutterApplication') {
        return AndroidEmbeddingVersionResult(AndroidEmbeddingVersion.v1,
            '${appManifestFile.absolute.path} uses `android:name="io.flutter.app.FlutterApplication"`');
      }
    }
    for (final XmlElement metaData in document.findAllElements('meta-data')) {
      final String? name = metaData.getAttribute('android:name');
      if (name == 'flutterEmbedding') {
        final String? embeddingVersionString =
            metaData.getAttribute('android:value');
        if (embeddingVersionString == '1') {
          return AndroidEmbeddingVersionResult(AndroidEmbeddingVersion.v1,
              '${appManifestFile.absolute.path} `<meta-data android:name="flutterEmbedding"` has value 1');
        }
        if (embeddingVersionString == '2') {
          return AndroidEmbeddingVersionResult(AndroidEmbeddingVersion.v2,
              '${appManifestFile.absolute.path} `<meta-data android:name="flutterEmbedding"` has value 2');
        }
      }
    }
    return AndroidEmbeddingVersionResult(AndroidEmbeddingVersion.v1,
        'No `<meta-data android:name="flutterEmbedding" android:value="2"/>` in ${appManifestFile.absolute.path}');
  }
}

enum AndroidEmbeddingVersion {
  v1,
  v2,
}

class AndroidEmbeddingVersionResult {
  AndroidEmbeddingVersionResult(this.version, this.reason);

  AndroidEmbeddingVersion version;

  String reason;
}

// What the tool should do when encountering deprecated API in applications.
enum DeprecationBehavior {
  // The command being run does not care about deprecation status.
  none,
  // The command should continue and ignore the deprecation warning.
  ignore,
  // The command should exit the tool.
  exit,
}

class WebProject extends FlutterProjectPlatform {
  WebProject._(this.parent);

  final FlutterProject parent;

  @override
  String get pluginConfigKey => WebPlugin.kConfigKey;

  @override
  bool existsSync() {
    return parent.directory.childDirectory('web').existsSync() &&
        indexFile.existsSync();
  }

  Directory get libDirectory => parent.directory.childDirectory('lib');

  Directory get directory => parent.directory.childDirectory('web');

  File get indexFile =>
      parent.directory.childDirectory('web').childFile('index.html');

  Directory get dartpadToolDirectory =>
      parent.directory.childDirectory('.dart_tool').childDirectory('dartpad');

  Future<void> ensureReadyForPlatformSpecificTooling() async {
    await injectBuildTimePluginFiles(
      parent,
      destination: dartpadToolDirectory,
      webPlatform: true,
    );
  }
}

class FuchsiaProject {
  FuchsiaProject._(this.project);

  final FlutterProject project;

  Directory? _editableHostAppDirectory;
  Directory get editableHostAppDirectory =>
      _editableHostAppDirectory ??= project.directory.childDirectory('fuchsia');

  bool existsSync() => editableHostAppDirectory.existsSync();

  Directory? _meta;
  Directory get meta =>
      _meta ??= editableHostAppDirectory.childDirectory('meta');
}

// Combines success and a description into one object that can be returned
// together.
@visibleForTesting
class CompatibilityResult {
  CompatibilityResult(this.success, this.description);
  final bool success;
  final String description;
}

String? versionToParsableString(Version? version) {
  if (version == null) {
    return null;
  }

  return '${version.major}.${version.minor}.${version.patch}';
}
