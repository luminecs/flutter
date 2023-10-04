import 'percentile_utils.dart';
import 'timeline.dart';

const Set<String> kProfilingEvents = <String>{
  _kCpuProfile,
  _kGpuProfile,
  _kMemoryProfile,
};

// These field names need to be in-sync with:
// https://github.com/flutter/engine/blob/master/shell/profiling/sampling_profiler.cc
const String _kCpuProfile = 'CpuUsage';
const String _kGpuProfile = 'GpuUsage';
const String _kMemoryProfile = 'MemoryUsage';

enum ProfileType {
  CPU,

  GPU,

  Memory,
}

class ProfilingSummarizer {
  ProfilingSummarizer._(this.eventByType);

  static ProfilingSummarizer fromEvents(List<TimelineEvent> profilingEvents) {
    final Map<ProfileType, List<TimelineEvent>> eventsByType =
        <ProfileType, List<TimelineEvent>>{};
    for (final TimelineEvent event in profilingEvents) {
      assert(kProfilingEvents.contains(event.name));
      final ProfileType type = _getProfileType(event.name);
      eventsByType[type] ??= <TimelineEvent>[];
      eventsByType[type]!.add(event);
    }
    return ProfilingSummarizer._(eventsByType);
  }

  final Map<ProfileType, List<TimelineEvent>> eventByType;

  Map<String, dynamic> summarize() {
    final Map<String, dynamic> summary = <String, dynamic>{};
    summary.addAll(_summarize(ProfileType.CPU, 'cpu_usage'));
    summary.addAll(_summarize(ProfileType.GPU, 'gpu_usage'));
    summary.addAll(_summarize(ProfileType.Memory, 'memory_usage'));
    return summary;
  }

  Map<String, double> _summarize(ProfileType profileType, String name) {
    final Map<String, double> summary = <String, double>{};
    if (!hasProfilingInfo(profileType)) {
      return summary;
    }
    summary['average_$name'] = computeAverage(profileType);
    summary['90th_percentile_$name'] = computePercentile(profileType, 90);
    summary['99th_percentile_$name'] = computePercentile(profileType, 99);
    return summary;
  }

  bool hasProfilingInfo(ProfileType profileType) {
    if (eventByType.containsKey(profileType)) {
      return eventByType[profileType]!.isNotEmpty;
    } else {
      return false;
    }
  }

  double computeAverage(ProfileType profileType) {
    final List<TimelineEvent> events = eventByType[profileType]!;
    assert(events.isNotEmpty);
    final double total = events
        .map((TimelineEvent e) => _getProfileValue(profileType, e))
        .reduce((double a, double b) => a + b);
    return total / events.length;
  }

  double computePercentile(ProfileType profileType, double percentile) {
    final List<TimelineEvent> events = eventByType[profileType]!;
    assert(events.isNotEmpty);
    final List<double> doubles = events
        .map((TimelineEvent e) => _getProfileValue(profileType, e))
        .toList();
    return findPercentile(doubles, percentile);
  }

  static ProfileType _getProfileType(String? eventName) {
    switch (eventName) {
      case _kCpuProfile:
        return ProfileType.CPU;
      case _kGpuProfile:
        return ProfileType.GPU;
      case _kMemoryProfile:
        return ProfileType.Memory;
      default:
        throw Exception('Invalid profiling event: $eventName.');
    }
  }

  double _getProfileValue(ProfileType profileType, TimelineEvent e) {
    switch (profileType) {
      case ProfileType.CPU:
        return _getArgValue('total_cpu_usage', e);
      case ProfileType.GPU:
        return _getArgValue('gpu_usage', e);
      case ProfileType.Memory:
        final double dirtyMem = _getArgValue('dirty_memory_usage', e);
        final double ownedSharedMem =
            _getArgValue('owned_shared_memory_usage', e);
        return dirtyMem + ownedSharedMem;
    }
  }

  double _getArgValue(String argKey, TimelineEvent e) {
    assert(e.arguments!.containsKey(argKey));
    final dynamic argVal = e.arguments![argKey];
    assert(argVal is String);
    return double.parse(argVal as String);
  }
}
