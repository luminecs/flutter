import 'base/context.dart';
import 'base/file_system.dart';
import 'build_info.dart';

abstract class ApplicationPackageFactory {
  static ApplicationPackageFactory? get instance => context.get<ApplicationPackageFactory>();

  Future<ApplicationPackage?> getPackageForPlatform(
    TargetPlatform platform, {
    BuildInfo? buildInfo,
    File? applicationBinary,
  });
}

abstract class ApplicationPackage {
  ApplicationPackage({ required this.id });

  final String id;

  String? get name;

  String? get displayName => name;

  @override
  String toString() => displayName ?? id;
}

abstract class PrebuiltApplicationPackage implements ApplicationPackage {
  FileSystemEntity get applicationPackage;
}