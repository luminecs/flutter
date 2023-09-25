import '../base/context.dart';
import '../base/platform.dart';
import '../doctor_validator.dart';
import '../features.dart';
import 'fuchsia_sdk.dart';

FuchsiaWorkflow? get fuchsiaWorkflow => context.get<FuchsiaWorkflow>();

class FuchsiaWorkflow implements Workflow {
  FuchsiaWorkflow({
    required Platform platform,
    required FeatureFlags featureFlags,
    required FuchsiaArtifacts fuchsiaArtifacts,
  }) : _platform = platform,
       _featureFlags = featureFlags,
       _fuchsiaArtifacts = fuchsiaArtifacts;

  final Platform _platform;
  final FeatureFlags _featureFlags;
  final FuchsiaArtifacts _fuchsiaArtifacts;

  @override
  bool get appliesToHostPlatform => _featureFlags.isFuchsiaEnabled && (_platform.isLinux || _platform.isMacOS);

  @override
  bool get canListDevices {
    return _fuchsiaArtifacts.ffx != null;
  }

  @override
  bool get canLaunchDevices {
    return _fuchsiaArtifacts.ffx != null && _fuchsiaArtifacts.sshConfig != null;
  }

  @override
  bool get canListEmulators => false;
}