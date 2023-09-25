
class EnumIndex<E> {
  EnumIndex(List<E> enumValues)
    : _nameToValue = Map<String, E>.fromIterable(
        enumValues,
        key: _getSimpleName,
      ),
      _valueToName = Map<E, String>.fromIterable(
        enumValues,
        value: _getSimpleName,
      );

  final Map<String, E> _nameToValue;
  final Map<E, String> _valueToName;

  E lookupBySimpleName(String simpleName) => _nameToValue[simpleName]!;

  String toSimpleName(E enumValue) => _valueToName[enumValue]!;
}

String _getSimpleName(dynamic enumValue) {
  return enumValue.toString().split('.').last;
}