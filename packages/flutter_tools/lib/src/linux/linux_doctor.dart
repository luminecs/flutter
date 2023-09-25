
import 'package:process/process.dart';

import '../base/io.dart';
import '../base/user_messages.dart';
import '../base/version.dart';
import '../doctor_validator.dart';

class _VersionInfo {
  _VersionInfo(this.description) {
    final String? versionString = RegExp(r'[0-9]+\.[0-9]+(?:\.[0-9]+)?').firstMatch(description)?.group(0);
    number = Version.parse(versionString);
  }

  // The full info string reported by the binary.
  String description;

  // The parsed Version.
  Version? number;
}

class LinuxDoctorValidator extends DoctorValidator {
  LinuxDoctorValidator({
    required ProcessManager processManager,
    required UserMessages userMessages,
  }) : _processManager = processManager,
       _userMessages = userMessages,
       super('Linux toolchain - develop for Linux desktop');

  final ProcessManager _processManager;
  final UserMessages _userMessages;

  static const String kClangBinary = 'clang++';
  static const String kCmakeBinary = 'cmake';
  static const String kNinjaBinary = 'ninja';
  static const String kPkgConfigBinary = 'pkg-config';

  final Map<String, Version> _requiredBinaryVersions = <String, Version>{
    kClangBinary: Version(3, 4, 0),
    kCmakeBinary: Version(3, 10, 0),
    kNinjaBinary: Version(1, 8, 0),
    kPkgConfigBinary: Version(0, 29, 0),
  };

  final List<String> _requiredGtkLibraries = <String>[
    'gtk+-3.0',
    'glib-2.0',
    'gio-2.0',
  ];

  @override
  Future<ValidationResult> validate() async {
    ValidationType validationType = ValidationType.success;
    final List<ValidationMessage> messages = <ValidationMessage>[];

    final Map<String, _VersionInfo?> installedVersions = <String, _VersionInfo?>{
      // Sort the check to make the call order predictable for unit tests.
      for (final String binary in _requiredBinaryVersions.keys.toList()..sort())
        binary: await _getBinaryVersion(binary),
    };

    // Determine overall validation level.
    if (installedVersions.values.any((_VersionInfo? versionInfo) => versionInfo?.number == null)) {
      validationType = ValidationType.missing;
    } else if (installedVersions.keys.any((String binary) =>
          installedVersions[binary]!.number! < _requiredBinaryVersions[binary]!)) {
      validationType = ValidationType.partial;
    }

    // Message for Clang.
    {
      final _VersionInfo? version = installedVersions[kClangBinary];
      if (version == null || version.number == null) {
        messages.add(ValidationMessage.error(_userMessages.clangMissing));
      } else {
        assert(_requiredBinaryVersions.containsKey(kClangBinary));
        messages.add(ValidationMessage(version.description));
        final Version requiredVersion = _requiredBinaryVersions[kClangBinary]!;
        if (version.number! < requiredVersion) {
          messages.add(ValidationMessage.error(_userMessages.clangTooOld(requiredVersion.toString())));
        }
      }
    }

    // Message for CMake.
    {
      final _VersionInfo? version = installedVersions[kCmakeBinary];
      if (version == null || version.number == null) {
        messages.add(ValidationMessage.error(_userMessages.cmakeMissing));
      } else {
        assert(_requiredBinaryVersions.containsKey(kCmakeBinary));
        messages.add(ValidationMessage(version.description));
        final Version requiredVersion = _requiredBinaryVersions[kCmakeBinary]!;
        if (version.number! < requiredVersion) {
          messages.add(ValidationMessage.error(_userMessages.cmakeTooOld(requiredVersion.toString())));
        }
      }
    }

    // Message for ninja.
    {
      final _VersionInfo? version = installedVersions[kNinjaBinary];
      if (version == null || version.number == null) {
        messages.add(ValidationMessage.error(_userMessages.ninjaMissing));
      } else {
        assert(_requiredBinaryVersions.containsKey(kNinjaBinary));
        // The full version description is just the number, so add context.
        messages.add(ValidationMessage(_userMessages.ninjaVersion(version.description)));
        final Version requiredVersion = _requiredBinaryVersions[kNinjaBinary]!;
        if (version.number! < requiredVersion) {
          messages.add(ValidationMessage.error(_userMessages.ninjaTooOld(requiredVersion.toString())));
        }
      }
    }

    // Message for pkg-config.
    {
      final _VersionInfo? version = installedVersions[kPkgConfigBinary];
      if (version == null || version.number == null) {
        messages.add(ValidationMessage.error(_userMessages.pkgConfigMissing));
        // Exit early because we cannot validate libraries without pkg-config.
        return ValidationResult(validationType, messages);
      } else {
        assert(_requiredBinaryVersions.containsKey(kPkgConfigBinary));
        // The full version description is just the number, so add context.
        messages.add(ValidationMessage(_userMessages.pkgConfigVersion(version.description)));
        final Version requiredVersion = _requiredBinaryVersions[kPkgConfigBinary]!;
        if (version.number! < requiredVersion) {
          messages.add(ValidationMessage.error(_userMessages.pkgConfigTooOld(requiredVersion.toString())));
        }
      }
    }

    // Messages for libraries.
    {
      bool libraryMissing = false;
      for (final String library in _requiredGtkLibraries) {
        if (!await _libraryIsPresent(library)) {
          libraryMissing = true;
          break;
        }
      }
      if (libraryMissing) {
        validationType = ValidationType.missing;
        messages.add(ValidationMessage.error(_userMessages.gtkLibrariesMissing));
      }
    }

    return ValidationResult(validationType, messages);
  }

  Future<_VersionInfo?> _getBinaryVersion(String binary) async {
    ProcessResult? result;
    try {
      result = await _processManager.run(<String>[
        binary,
        '--version',
      ]);
    } on ArgumentError {
      // ignore error.
    } on ProcessException {
      // ignore error.
    }
    if (result == null || result.exitCode != 0) {
      return null;
    }
    final String firstLine = (result.stdout as String).split('\n').first.trim();
    return _VersionInfo(firstLine);
  }

  Future<bool> _libraryIsPresent(String library) async {
    ProcessResult? result;
    try {
      result = await _processManager.run(<String>[
        'pkg-config',
        '--exists',
        library,
      ]);
    } on ArgumentError {
      // ignore error.
    }
    return (result?.exitCode ?? 1) == 0;
  }
}