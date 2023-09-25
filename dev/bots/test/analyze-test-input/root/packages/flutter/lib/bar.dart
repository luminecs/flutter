
class _DebugOnly {
  const _DebugOnly();
}

const _DebugOnly _debugOnly = _DebugOnly();
const bool kDebugMode = bool.fromEnvironment('test-only');

class Foo {
  @_debugOnly
  final Map<String, String>? foo = kDebugMode ? <String, String>{} : null;

  @_debugOnly
  final Map<String, String>? bar = kDebugMode ? null : <String, String>{};
}