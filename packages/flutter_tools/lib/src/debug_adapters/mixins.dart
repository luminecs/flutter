import '../base/io.dart';

mixin PidTracker {
  final Set<int> pidsToTerminate = <int>{};

  void terminatePids(ProcessSignal signal) {
    pidsToTerminate.forEach(signal.send);
  }
}
