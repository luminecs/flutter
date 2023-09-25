import '../base/platform.dart';
import '../doctor_validator.dart';
import '../features.dart';

class MacOSWorkflow implements Workflow {
  const MacOSWorkflow({
    required Platform platform,
    required FeatureFlags featureFlags,
  }) : _platform = platform,
       _featureFlags = featureFlags;

  final Platform _platform;
  final FeatureFlags _featureFlags;

  @override
  bool get appliesToHostPlatform => _platform.isMacOS && _featureFlags.isMacOSEnabled;

  @override
  bool get canLaunchDevices => _platform.isMacOS && _featureFlags.isMacOSEnabled;

  @override
  bool get canListDevices => _platform.isMacOS && _featureFlags.isMacOSEnabled;

  @override
  bool get canListEmulators => false;
}