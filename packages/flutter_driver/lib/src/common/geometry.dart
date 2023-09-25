
import 'enum_util.dart';
import 'find.dart';
import 'message.dart';

enum OffsetType {
  topLeft,

  topRight,

  bottomLeft,

  bottomRight,

  center,
}

EnumIndex<OffsetType> _offsetTypeIndex = EnumIndex<OffsetType>(OffsetType.values);

class GetOffset extends CommandWithTarget {
  GetOffset(super.finder,  this.offsetType, { super.timeout });

  GetOffset.deserialize(super.json, super.finderFactory)
      : offsetType = _offsetTypeIndex.lookupBySimpleName(json['offsetType']!),
        super.deserialize();

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'offsetType': _offsetTypeIndex.toSimpleName(offsetType),
  });

  final OffsetType offsetType;

  @override
  String get kind => 'get_offset';
}

class GetOffsetResult extends Result {
  const GetOffsetResult({ this.dx = 0.0, this.dy = 0.0});

  final double dx;

  final double dy;

  static GetOffsetResult fromJson(Map<String, dynamic> json) {
    return GetOffsetResult(
      dx: json['dx'] as double,
      dy: json['dy'] as double,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, double>{
    'dx': dx,
    'dy': dy,
  };
}