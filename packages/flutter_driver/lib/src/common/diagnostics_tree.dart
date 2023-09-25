
import 'enum_util.dart';
import 'find.dart';
import 'message.dart';

enum DiagnosticsType {
  renderObject,

  widget,
}

EnumIndex<DiagnosticsType> _diagnosticsTypeIndex = EnumIndex<DiagnosticsType>(DiagnosticsType.values);

class GetDiagnosticsTree extends CommandWithTarget {
  GetDiagnosticsTree(super.finder, this.diagnosticsType, {
    this.subtreeDepth = 0,
    this.includeProperties = true,
    super.timeout,
  });

  GetDiagnosticsTree.deserialize(super.json, super.finderFactory)
      : subtreeDepth = int.parse(json['subtreeDepth']!),
        includeProperties = json['includeProperties'] == 'true',
        diagnosticsType = _diagnosticsTypeIndex.lookupBySimpleName(json['diagnosticsType']!),
        super.deserialize();

  final int subtreeDepth;

  final bool includeProperties;

  final DiagnosticsType diagnosticsType;

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'subtreeDepth': subtreeDepth.toString(),
    'includeProperties': includeProperties.toString(),
    'diagnosticsType': _diagnosticsTypeIndex.toSimpleName(diagnosticsType),
  });

  @override
  String get kind => 'get_diagnostics_tree';
}

class DiagnosticsTreeResult extends Result {
  const DiagnosticsTreeResult(this.json);

  final Map<String, dynamic> json;

  @override
  Map<String, dynamic> toJson() => json;
}