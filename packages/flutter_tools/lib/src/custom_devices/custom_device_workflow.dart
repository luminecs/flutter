
import 'package:meta/meta.dart';

import '../doctor_validator.dart';
import '../features.dart';

@immutable
class CustomDeviceWorkflow implements Workflow {
  const CustomDeviceWorkflow({
    required FeatureFlags featureFlags
  }) : _featureFlags = featureFlags;

  final FeatureFlags _featureFlags;

  @override
  bool get appliesToHostPlatform => _featureFlags.areCustomDevicesEnabled;

  @override
  bool get canLaunchDevices => _featureFlags.areCustomDevicesEnabled;

  @override
  bool get canListDevices => _featureFlags.areCustomDevicesEnabled;

  @override
  bool get canListEmulators => false;
}