
import 'dart:io' as io show Platform, stdin, stdout;

abstract class Platform {
  const Platform();

  int get numberOfProcessors;

  String get pathSeparator;

  String get operatingSystem;

  String get operatingSystemVersion;

  String get localHostname;

  bool get isLinux => operatingSystem == 'linux';

  bool get isMacOS => operatingSystem == 'macos';

  bool get isWindows => operatingSystem == 'windows';

  bool get isAndroid => operatingSystem == 'android';

  bool get isIOS => operatingSystem == 'ios';

  bool get isFuchsia => operatingSystem == 'fuchsia';

  Map<String, String> get environment;

  String get executable;

  String get resolvedExecutable;

  Uri get script;

  List<String> get executableArguments;

  String? get packageConfig;

  String get version;

  bool get stdinSupportsAnsi;

  bool get stdoutSupportsAnsi;

  String get localeName;
}

class LocalPlatform extends Platform {
  const LocalPlatform();

  @override
  int get numberOfProcessors => io.Platform.numberOfProcessors;

  @override
  String get pathSeparator => io.Platform.pathSeparator;

  @override
  String get operatingSystem => io.Platform.operatingSystem;

  @override
  String get operatingSystemVersion => io.Platform.operatingSystemVersion;

  @override
  String get localHostname => io.Platform.localHostname;

  @override
  Map<String, String> get environment => io.Platform.environment;

  @override
  String get executable => io.Platform.executable;

  @override
  String get resolvedExecutable => io.Platform.resolvedExecutable;

  @override
  Uri get script => io.Platform.script;

  @override
  List<String> get executableArguments => io.Platform.executableArguments;

  @override
  String? get packageConfig => io.Platform.packageConfig;

  @override
  String get version => io.Platform.version;

  @override
  bool get stdinSupportsAnsi => io.stdin.supportsAnsiEscapes;

  @override
  bool get stdoutSupportsAnsi => io.stdout.supportsAnsiEscapes;

  @override
  String get localeName => io.Platform.localeName;
}

final Uri _empty = Uri.parse('');

class FakePlatform extends Platform {
  FakePlatform({
    this.numberOfProcessors = 1,
    this.pathSeparator = '/',
    this.operatingSystem = 'linux',
    this.operatingSystemVersion = '',
    this.localHostname = '',
    this.environment = const <String, String>{},
    this.executable = '',
    this.resolvedExecutable = '',
    Uri? script,
    this.executableArguments = const <String>[],
    this.packageConfig,
    this.version = '',
    this.stdinSupportsAnsi = false,
    this.stdoutSupportsAnsi = false,
    this.localeName = '',
  }) : script = script ?? _empty;

  FakePlatform.fromPlatform(Platform platform)
      : numberOfProcessors = platform.numberOfProcessors,
        pathSeparator = platform.pathSeparator,
        operatingSystem = platform.operatingSystem,
        operatingSystemVersion = platform.operatingSystemVersion,
        localHostname = platform.localHostname,
        environment = Map<String, String>.from(platform.environment),
        executable = platform.executable,
        resolvedExecutable = platform.resolvedExecutable,
        script = platform.script,
        executableArguments =
            List<String>.from(platform.executableArguments),
        packageConfig = platform.packageConfig,
        version = platform.version,
        stdinSupportsAnsi = platform.stdinSupportsAnsi,
        stdoutSupportsAnsi = platform.stdoutSupportsAnsi,
        localeName = platform.localeName;

  @override
  int numberOfProcessors;

  @override
  String pathSeparator;

  @override
  String operatingSystem;

  @override
  String operatingSystemVersion;

  @override
  String localHostname;

  @override
  Map<String, String> environment;

  @override
  String executable;

  @override
  String resolvedExecutable;

  @override
  Uri script;

  @override
  List<String> executableArguments;

  @override
  String? packageConfig;

  @override
  String version;

  @override
  bool stdinSupportsAnsi;

  @override
  bool stdoutSupportsAnsi;

  @override
  String localeName;
}