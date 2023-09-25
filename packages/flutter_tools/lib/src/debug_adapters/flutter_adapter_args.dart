
import 'package:dds/dap.dart';

class FlutterAttachRequestArguments
    extends DartCommonLaunchAttachRequestArguments
    implements AttachRequestArguments {
  FlutterAttachRequestArguments({
    this.toolArgs,
    this.customTool,
    this.customToolReplacesArgs,
    this.vmServiceUri,
    this.vmServiceInfoFile,
    this.program,
    super.restart,
    super.name,
    super.cwd,
    super.env,
    super.additionalProjectPaths,
    super.allowAnsiColorOutput,
    super.debugSdkLibraries,
    super.debugExternalPackageLibraries,
    super.evaluateGettersInDebugViews,
    super.evaluateToStringInDebugViews,
    super.sendLogsToClient,
    super.sendCustomProgressEvents,
  });

  FlutterAttachRequestArguments.fromMap(super.obj)
      : toolArgs = (obj['toolArgs'] as List<Object?>?)?.cast<String>(),
        customTool = obj['customTool'] as String?,
        customToolReplacesArgs = obj['customToolReplacesArgs'] as int?,
        vmServiceUri = obj['vmServiceUri'] as String?,
        vmServiceInfoFile = obj['vmServiceInfoFile'] as String?,
        program = obj['program'] as String?,
        super.fromMap();

  static FlutterAttachRequestArguments fromJson(Map<String, Object?> obj) =>
      FlutterAttachRequestArguments.fromMap(obj);

  final List<String>? toolArgs;

  final String? customTool;

  final int? customToolReplacesArgs;

  final String? vmServiceUri;

  final String? vmServiceInfoFile;

  final String? program;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        ...super.toJson(),
        if (toolArgs != null) 'toolArgs': toolArgs,
        if (customTool != null) 'customTool': customTool,
        if (customToolReplacesArgs != null)
          'customToolReplacesArgs': customToolReplacesArgs,
        if (vmServiceUri != null) 'vmServiceUri': vmServiceUri,
      };
}

class FlutterLaunchRequestArguments
    extends DartCommonLaunchAttachRequestArguments
    implements LaunchRequestArguments {
  FlutterLaunchRequestArguments({
    this.noDebug,
    required this.program,
    this.args,
    this.toolArgs,
    this.customTool,
    this.customToolReplacesArgs,
    super.restart,
    super.name,
    super.cwd,
    super.env,
    super.additionalProjectPaths,
    super.allowAnsiColorOutput,
    super.debugSdkLibraries,
    super.debugExternalPackageLibraries,
    super.evaluateGettersInDebugViews,
    super.evaluateToStringInDebugViews,
    super.sendLogsToClient,
    super.sendCustomProgressEvents,
  });

  FlutterLaunchRequestArguments.fromMap(super.obj)
      : noDebug = obj['noDebug'] as bool?,
        program = obj['program'] as String?,
        args = (obj['args'] as List<Object?>?)?.cast<String>(),
        toolArgs = (obj['toolArgs'] as List<Object?>?)?.cast<String>(),
        customTool = obj['customTool'] as String?,
        customToolReplacesArgs = obj['customToolReplacesArgs'] as int?,
        super.fromMap();

  @override
  final bool? noDebug;

  final String? program;

  final List<String>? args;

  final List<String>? toolArgs;

  final String? customTool;

  final int? customToolReplacesArgs;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        ...super.toJson(),
        if (noDebug != null) 'noDebug': noDebug,
        if (program != null) 'program': program,
        if (args != null) 'args': args,
        if (toolArgs != null) 'toolArgs': toolArgs,
        if (customTool != null) 'customTool': customTool,
        if (customToolReplacesArgs != null)
          'customToolReplacesArgs': customToolReplacesArgs,
      };

  static FlutterLaunchRequestArguments fromJson(Map<String, Object?> obj) =>
      FlutterLaunchRequestArguments.fromMap(obj);
}