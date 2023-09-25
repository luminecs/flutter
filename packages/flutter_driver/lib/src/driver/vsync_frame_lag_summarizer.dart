
import 'percentile_utils.dart';
import 'timeline.dart';

const String _kPlatformVsyncEvent = 'VSYNC';
const String _kUIThreadVsyncProcessEvent = 'VsyncProcessCallback';

const Set<String> kVsyncTimelineEventNames = <String>{
  _kUIThreadVsyncProcessEvent,
  _kPlatformVsyncEvent,
};

class VsyncFrameLagSummarizer {
  VsyncFrameLagSummarizer(this.vsyncEvents);

  final List<TimelineEvent> vsyncEvents;

  double computeAverageVsyncFrameLag() {
    final List<double> vsyncFrameLags =
        _computePlatformToFlutterVsyncBeginLags();
    if (vsyncFrameLags.isEmpty) {
      return 0;
    }

    final double total = vsyncFrameLags.reduce((double a, double b) => a + b);
    return total / vsyncFrameLags.length;
  }

  double computePercentileVsyncFrameLag(double percentile) {
    final List<double> vsyncFrameLags =
        _computePlatformToFlutterVsyncBeginLags();
    if (vsyncFrameLags.isEmpty) {
      return 0;
    }
    return findPercentile(vsyncFrameLags, percentile);
  }

  List<double> _computePlatformToFlutterVsyncBeginLags() {
    int platformIdx = -1;
    final List<double> result = <double>[];
    for (int i = 0; i < vsyncEvents.length; i++) {
      final TimelineEvent event = vsyncEvents[i];
      if (event.phase != 'B') {
        continue;
      }
      if (event.name == _kPlatformVsyncEvent) {
        // There was a vsync that resulted in a frame not being built.
        // This needs to be penalized.
        if (platformIdx != -1) {
          final int prevTS = vsyncEvents[platformIdx].timestampMicros!;
          result.add((event.timestampMicros! - prevTS).toDouble());
        }
        platformIdx = i;
      } else if (platformIdx != -1) {
        final int platformTS = vsyncEvents[platformIdx].timestampMicros!;
        result.add((event.timestampMicros! - platformTS).toDouble());
        platformIdx = -1;
      }
    }
    return result;
  }
}