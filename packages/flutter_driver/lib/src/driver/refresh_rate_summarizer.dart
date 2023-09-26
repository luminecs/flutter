import 'timeline.dart';

const String kUIThreadVsyncProcessEvent = 'VsyncProcessCallback';

class RefreshRateSummary {
  factory RefreshRateSummary({required List<TimelineEvent> vsyncEvents}) {
    return RefreshRateSummary._(
        refreshRates: _computeRefreshRates(vsyncEvents));
  }

  RefreshRateSummary._({required List<double> refreshRates}) {
    _numberOfTotalFrames = refreshRates.length;
    for (final double refreshRate in refreshRates) {
      if ((refreshRate - 30).abs() < _kErrorMargin) {
        _numberOf30HzFrames++;
        continue;
      }
      if ((refreshRate - 60).abs() < _kErrorMargin) {
        _numberOf60HzFrames++;
        continue;
      }
      if ((refreshRate - 80).abs() < _kErrorMargin) {
        _numberOf80HzFrames++;
        continue;
      }
      if ((refreshRate - 90).abs() < _kErrorMargin) {
        _numberOf90HzFrames++;
        continue;
      }
      if ((refreshRate - 120).abs() < _kErrorMargin) {
        _numberOf120HzFrames++;
        continue;
      }
      _framesWithIllegalRefreshRate.add(refreshRate);
    }
    assert(_numberOfTotalFrames ==
        _numberOf30HzFrames +
            _numberOf60HzFrames +
            _numberOf80HzFrames +
            _numberOf90HzFrames +
            _numberOf120HzFrames +
            _framesWithIllegalRefreshRate.length);
  }

  // The error margin to determine the frame refresh rate.
  // For example, when we calculated a frame that has a refresh rate of 65, we consider the frame to be a 60Hz frame.
  // Can be adjusted if necessary.
  static const double _kErrorMargin = 6.0;

  double get percentageOf30HzFrames => _numberOfTotalFrames > 0
      ? _numberOf30HzFrames / _numberOfTotalFrames * 100
      : 0;

  double get percentageOf60HzFrames => _numberOfTotalFrames > 0
      ? _numberOf60HzFrames / _numberOfTotalFrames * 100
      : 0;

  double get percentageOf80HzFrames => _numberOfTotalFrames > 0
      ? _numberOf80HzFrames / _numberOfTotalFrames * 100
      : 0;

  double get percentageOf90HzFrames => _numberOfTotalFrames > 0
      ? _numberOf90HzFrames / _numberOfTotalFrames * 100
      : 0;

  double get percentageOf120HzFrames => _numberOfTotalFrames > 0
      ? _numberOf120HzFrames / _numberOfTotalFrames * 100
      : 0;

  List<double> get framesWithIllegalRefreshRate =>
      _framesWithIllegalRefreshRate;

  int _numberOf30HzFrames = 0;
  int _numberOf60HzFrames = 0;
  int _numberOf80HzFrames = 0;
  int _numberOf90HzFrames = 0;
  int _numberOf120HzFrames = 0;
  int _numberOfTotalFrames = 0;

  final List<double> _framesWithIllegalRefreshRate = <double>[];

  static List<double> _computeRefreshRates(List<TimelineEvent> vsyncEvents) {
    final List<double> result = <double>[];
    for (int i = 0; i < vsyncEvents.length; i++) {
      final TimelineEvent event = vsyncEvents[i];
      if (event.phase != 'B') {
        continue;
      }
      assert(event.name == kUIThreadVsyncProcessEvent);
      assert(event.arguments != null);
      final Map<String, dynamic> arguments = event.arguments!;
      const double nanosecondsPerSecond = 1e+9;
      final int startTimeInNanoseconds =
          int.parse(arguments['StartTime'] as String);
      final int targetTimeInNanoseconds =
          int.parse(arguments['TargetTime'] as String);
      final int frameDurationInNanoseconds =
          targetTimeInNanoseconds - startTimeInNanoseconds;
      final double refreshRate =
          nanosecondsPerSecond / frameDurationInNanoseconds;
      result.add(refreshRate);
    }
    return result;
  }
}
