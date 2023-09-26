import 'percentile_utils.dart';
import 'timeline.dart';

const String kSceneDisplayLagEvent = 'SceneDisplayLag';

const String _kVsyncTransitionsMissed = 'vsync_transitions_missed';

class SceneDisplayLagSummarizer {
  SceneDisplayLagSummarizer(this.sceneDisplayLagEvents) {
    for (final TimelineEvent event in sceneDisplayLagEvents) {
      assert(event.name == kSceneDisplayLagEvent);
    }
  }

  final List<TimelineEvent> sceneDisplayLagEvents;

  double computeAverageVsyncTransitionsMissed() {
    if (sceneDisplayLagEvents.isEmpty) {
      return 0;
    }

    final double total = sceneDisplayLagEvents
        .map(_getVsyncTransitionsMissed)
        .reduce((double a, double b) => a + b);
    return total / sceneDisplayLagEvents.length;
  }

  double computePercentileVsyncTransitionsMissed(double percentile) {
    if (sceneDisplayLagEvents.isEmpty) {
      return 0;
    }

    final List<double> doubles =
        sceneDisplayLagEvents.map(_getVsyncTransitionsMissed).toList();
    return findPercentile(doubles, percentile);
  }

  double _getVsyncTransitionsMissed(TimelineEvent e) {
    assert(e.name == kSceneDisplayLagEvent);
    assert(e.arguments!.containsKey(_kVsyncTransitionsMissed));
    final dynamic transitionsMissed = e.arguments![_kVsyncTransitionsMissed];
    assert(transitionsMissed is String);
    return double.parse(transitionsMissed as String);
  }
}
