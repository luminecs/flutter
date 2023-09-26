import '../base/platform.dart';
import '../doctor_validator.dart';
import '../features.dart';

class LinuxWorkflow implements Workflow {
  const LinuxWorkflow({
    required Platform platform,
    required FeatureFlags featureFlags,
  })  : _platform = platform,
        _featureFlags = featureFlags;

  final Platform _platform;
  final FeatureFlags _featureFlags;

  @override
  bool get appliesToHostPlatform =>
      _platform.isLinux && _featureFlags.isLinuxEnabled;

  @override
  bool get canLaunchDevices =>
      _platform.isLinux && _featureFlags.isLinuxEnabled;

  @override
  bool get canListDevices => _platform.isLinux && _featureFlags.isLinuxEnabled;

  @override
  bool get canListEmulators => false;
}
