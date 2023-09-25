
import 'package:process/process.dart';

import '../base/config.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/os.dart';
import '../base/platform.dart';
import '../base/process.dart';
import '../base/version.dart';
import 'android_studio.dart';

const String _javaExecutable = 'java';

class Java {

  Java({
    required this.javaHome,
    required this.binaryPath,
    required Logger logger,
    required FileSystem fileSystem,
    required OperatingSystemUtils os,
    required Platform platform,
    required ProcessManager processManager,
  }): _logger = logger,
      _fileSystem = fileSystem,
      _os = os,
      _platform = platform,
      _processManager = processManager,
      _processUtils = ProcessUtils(processManager: processManager, logger: logger);

  static String javaHomeEnvironmentVariable = 'JAVA_HOME';

  static Java? find({
    required Config config,
    required AndroidStudio? androidStudio,
    required Logger logger,
    required FileSystem fileSystem,
    required Platform platform,
    required ProcessManager processManager,
  }) {
    final OperatingSystemUtils os = OperatingSystemUtils(
      fileSystem: fileSystem,
      logger: logger,
      platform: platform,
      processManager: processManager
    );
    final String? home = _findJavaHome(
      config: config,
      logger: logger,
      androidStudio: androidStudio,
      platform: platform
    );
    final String? binary = _findJavaBinary(
      logger: logger,
      javaHome: home,
      fileSystem: fileSystem,
      operatingSystemUtils: os,
      platform: platform
    );

    if (binary == null) {
      return null;
    }

    return Java(
      javaHome: home,
      binaryPath: binary,
      logger: logger,
      fileSystem: fileSystem,
      os: os,
      platform: platform,
      processManager: processManager,
    );
  }

  final String? javaHome;

  final String binaryPath;

  final Logger _logger;
  final FileSystem _fileSystem;
  final OperatingSystemUtils _os;
  final Platform _platform;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;

  Map<String, String> get environment {
    return <String, String>{
      if (javaHome != null) javaHomeEnvironmentVariable: javaHome!,
      'PATH': _fileSystem.path.dirname(binaryPath) +
                        _os.pathVarSeparator +
                        _platform.environment['PATH']!,
    };
  }

  late final Version? version = (() {
    final RunResult result = _processUtils.runSync(
      <String>[binaryPath, '--version'],
      environment: environment,
    );
    if (result.exitCode != 0) {
      _logger.printTrace('java --version failed: exitCode: ${result.exitCode}'
        ' stdout: ${result.stdout} stderr: ${result.stderr}');
    }
    final String rawVersionOutput = result.stdout;
    final List<String> versionLines = rawVersionOutput.split('\n');
    // Should look something like 'openjdk 19.0.2 2023-01-17'.
    final String longVersionText = versionLines.length >= 2 ? versionLines[1] : versionLines[0];

    // The contents that matter come in the format '11.0.18' or '1.8.0_202'.
    final RegExp jdkVersionRegex = RegExp(r'\d+\.\d+(\.\d+(?:_\d+)?)?');
    final Iterable<RegExpMatch> matches =
        jdkVersionRegex.allMatches(rawVersionOutput);
    if (matches.isEmpty) {
      _logger.printWarning(_formatJavaVersionWarning(rawVersionOutput));
      return null;
    }
    final String? version = matches.first.group(0);
    if (version == null || version.split('_').isEmpty) {
      _logger.printWarning(_formatJavaVersionWarning(rawVersionOutput));
      return null;
    }

    // Trim away _d+ from versions 1.8 and below.
    final String versionWithoutBuildInfo = version.split('_').first;

    final Version? parsedVersion = Version.parse(versionWithoutBuildInfo);
    if (parsedVersion == null) {
      return null;
    }
    return Version.withText(
      parsedVersion.major,
      parsedVersion.minor,
      parsedVersion.patch,
      longVersionText,
    );
  })();

  bool canRun() {
    return _processManager.canRun(binaryPath);
  }
}

String? _findJavaHome({
  required Config config,
  required Logger logger,
  required AndroidStudio? androidStudio,
  required Platform platform,
}) {
  final Object? configured = config.getValue('jdk-dir');
  if (configured != null) {
    return configured as String;
  }

  final String? androidStudioJavaPath = androidStudio?.javaPath;
  if (androidStudioJavaPath != null) {
    return androidStudioJavaPath;
  }

  final String? javaHomeEnv = platform.environment[Java.javaHomeEnvironmentVariable];
  if (javaHomeEnv != null) {
    return javaHomeEnv;
  }
  return null;
}

String? _findJavaBinary({
  required Logger logger,
  required String? javaHome,
  required FileSystem fileSystem,
  required OperatingSystemUtils operatingSystemUtils,
  required Platform platform,
}) {
  if (javaHome != null) {
    return fileSystem.path.join(javaHome, 'bin', 'java');
  }

  // Fallback to PATH based lookup.
  return operatingSystemUtils.which(_javaExecutable)?.path;
}

// Returns a user visible String that says the tool failed to parse
// the version of java along with the output.
String _formatJavaVersionWarning(String javaVersionRaw) {
  return 'Could not parse java version from: \n'
    '$javaVersionRaw \n'
    'If there is a version please look for an existing bug '
    'https://github.com/flutter/flutter/issues/ '
    'and if one does not exist file a new issue.';
}