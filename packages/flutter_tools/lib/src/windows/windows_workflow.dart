import '../base/context.dart';
import '../base/platform.dart';
import '../doctor_validator.dart';
import '../features.dart';

WindowsWorkflow? get windowsWorkflow => context.get<WindowsWorkflow>();

class WindowsWorkflow implements Workflow {
  const WindowsWorkflow({
    required Platform platform,
    required FeatureFlags featureFlags,
  })  : _platform = platform,
        _featureFlags = featureFlags;

  final Platform _platform;
  final FeatureFlags _featureFlags;

  @override
  bool get appliesToHostPlatform =>
      _platform.isWindows && _featureFlags.isWindowsEnabled;

  @override
  bool get canLaunchDevices =>
      _platform.isWindows && _featureFlags.isWindowsEnabled;

  @override
  bool get canListDevices =>
      _platform.isWindows && _featureFlags.isWindowsEnabled;

  @override
  bool get canListEmulators => false;
}
