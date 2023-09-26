import 'timeline.dart';

const Set<String> kGCRootEvents = <String>{
  'CollectNewGeneration',
  'CollectOldGeneration',
  'EvacuateNewGeneration',
  'StartConcurrentMark',
};

class GCSummarizer {
  GCSummarizer._(this.totalGCTimeMillis);

  static GCSummarizer fromEvents(List<TimelineEvent> gcEvents) {
    double totalGCTimeMillis = 0;
    TimelineEvent? lastGCBeginEvent;

    for (final TimelineEvent event in gcEvents) {
      if (!kGCRootEvents.contains(event.name)) {
        continue;
      }
      if (event.phase == 'B') {
        lastGCBeginEvent = event;
      } else if (lastGCBeginEvent != null) {
        // These events must not overlap.
        assert(event.name == lastGCBeginEvent.name,
            'Expected "${lastGCBeginEvent.name}" got "${event.name}"');
        final double st = lastGCBeginEvent.timestampMicros!.toDouble();
        final double end = event.timestampMicros!.toDouble();
        lastGCBeginEvent = null;
        totalGCTimeMillis += (end - st) / 1000;
      }
    }

    return GCSummarizer._(totalGCTimeMillis);
  }

  final double totalGCTimeMillis;
}
