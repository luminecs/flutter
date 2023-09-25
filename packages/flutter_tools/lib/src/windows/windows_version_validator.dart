import '../base/os.dart';
import '../doctor_validator.dart';

const List<String> kUnsupportedVersions = <String>[
  '6',
  '7',
  '8',
];

const String kWindowsOSVersionSemVerPattern = r'([0-9]+)\.([0-9]+)\.([0-9\.]+)';

class WindowsVersionValidator extends DoctorValidator {
  const WindowsVersionValidator({
    required OperatingSystemUtils operatingSystemUtils,
  })  : _operatingSystemUtils = operatingSystemUtils,
        super('Windows Version');

  final OperatingSystemUtils _operatingSystemUtils;

  @override
  Future<ValidationResult> validate() async {
    final RegExp regex =
        RegExp(kWindowsOSVersionSemVerPattern, multiLine: true);
    final String commandResult = _operatingSystemUtils.name;
    final Iterable<RegExpMatch> matches = regex.allMatches(commandResult);

    // Use the string split method to extract the major version
    // and check against the [kUnsupportedVersions] list
    final ValidationType windowsVersionStatus;
    final String statusInfo;
    if (matches.length == 1 &&
        !kUnsupportedVersions.contains(matches.elementAt(0).group(1))) {
      windowsVersionStatus = ValidationType.success;
      statusInfo = 'Installed version of Windows is version 10 or higher';
    } else {
      windowsVersionStatus = ValidationType.missing;
      statusInfo =
          'Unable to determine Windows version (command `ver` returned $commandResult)';
    }

    return ValidationResult(
      windowsVersionStatus,
      const <ValidationMessage>[],
      statusInfo: statusInfo,
    );
  }
}