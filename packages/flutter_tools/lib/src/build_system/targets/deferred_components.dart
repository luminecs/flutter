
import 'package:meta/meta.dart';

import '../../android/deferred_components_gen_snapshot_validator.dart';
import '../../base/deferred_component.dart';
import '../../build_info.dart';
import '../../project.dart';
import '../build_system.dart';
import '../depfile.dart';
import 'android.dart';

class DeferredComponentsGenSnapshotValidatorTarget extends Target {
  DeferredComponentsGenSnapshotValidatorTarget({
    required this.deferredComponentsDependencies,
    required this.nonDeferredComponentsDependencies,
    this.title,
    this.exitOnFail = true,
  });

  final List<AndroidAotDeferredComponentsBundle> deferredComponentsDependencies;
  final List<Target> nonDeferredComponentsDependencies;

  final String? title;

  final bool exitOnFail;

  List<String> get _abis {
    final List<String> abis = <String>[];
    for (final AndroidAotDeferredComponentsBundle target in deferredComponentsDependencies) {
      if (deferredComponentsTargets.contains(target.name)) {
        abis.add(
          getAndroidArchForName(getNameForTargetPlatform(target.dependency.targetPlatform)).archName
        );
      }
    }
    return abis;
  }

  @override
  String get name => 'deferred_components_gen_snapshot_validator';

  @override
  List<Source> get inputs => const <Source>[];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  List<String> get depfiles => <String>[
    'flutter_$name.d',
  ];

  @override
  List<Target> get dependencies {
    final List<Target> deps = <Target>[CompositeTarget(deferredComponentsDependencies)];
    deps.addAll(nonDeferredComponentsDependencies);
    return deps;
  }

  @visibleForTesting
  DeferredComponentsGenSnapshotValidator? validator;

  @override
  Future<void> build(Environment environment) async {
    validator = DeferredComponentsGenSnapshotValidator(
      environment,
      title: title,
      exitOnFail: exitOnFail,
    );

    final List<LoadingUnit> generatedLoadingUnits = LoadingUnit.parseGeneratedLoadingUnits(
        environment.outputDir,
        environment.logger,
        abis: _abis
    );

    validator!
      ..checkAppAndroidManifestComponentLoadingUnitMapping(
          FlutterProject.current().manifest.deferredComponents ?? <DeferredComponent>[],
          generatedLoadingUnits,
      )
      ..checkAgainstLoadingUnitsCache(generatedLoadingUnits)
      ..writeLoadingUnitsCache(generatedLoadingUnits);

    validator!.handleResults();

    environment.depFileService.writeToFile(
      Depfile(validator!.inputs, validator!.outputs),
      environment.buildDir.childFile('flutter_$name.d'),
    );
  }
}