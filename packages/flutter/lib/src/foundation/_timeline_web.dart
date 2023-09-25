import 'dart:js_interop';

double get performanceTimestamp => 1000 * _performance.now();

@JS()
@staticInterop
class _DomPerformance {}

@JS('performance')
external _DomPerformance get _performance;

extension _DomPerformanceExtension on _DomPerformance {
  @JS()
  external double now();
}