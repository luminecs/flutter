import 'dart:ui';

Duration kBuildBudget = const Duration(milliseconds: 16);
// TODO(CareF): Automatically calculate the refresh budget (#61958)

class FrameTimingSummarizer {
  factory FrameTimingSummarizer(
    List<FrameTiming> data, {
    int? newGenGCCount,
    int? oldGenGCCount,
  }) {
    assert(data.isNotEmpty);
    final List<Duration> frameBuildTime = List<Duration>.unmodifiable(
      data.map<Duration>((FrameTiming datum) => datum.buildDuration),
    );
    final List<Duration> frameBuildTimeSorted =
        List<Duration>.from(frameBuildTime)..sort();
    final List<Duration> frameRasterizerTime = List<Duration>.unmodifiable(
      data.map<Duration>((FrameTiming datum) => datum.rasterDuration),
    );
    final List<Duration> frameRasterizerTimeSorted =
        List<Duration>.from(frameRasterizerTime)..sort();
    final List<Duration> vsyncOverhead = List<Duration>.unmodifiable(
      data.map<Duration>((FrameTiming datum) => datum.vsyncOverhead),
    );
    final List<int> layerCacheCounts = List<int>.unmodifiable(
      data.map<int>((FrameTiming datum) => datum.layerCacheCount),
    );
    final List<int> layerCacheCountsSorted = List<int>.from(layerCacheCounts)
      ..sort();
    final List<int> layerCacheBytes = List<int>.unmodifiable(
      data.map<int>((FrameTiming datum) => datum.layerCacheBytes),
    );
    final List<int> layerCacheBytesSorted = List<int>.from(layerCacheBytes)
      ..sort();
    final List<int> pictureCacheCounts = List<int>.unmodifiable(
      data.map<int>((FrameTiming datum) => datum.pictureCacheCount),
    );
    final List<int> pictureCacheCountsSorted =
        List<int>.from(pictureCacheCounts)..sort();
    final List<int> pictureCacheBytes = List<int>.unmodifiable(
      data.map<int>((FrameTiming datum) => datum.pictureCacheBytes),
    );
    final List<int> pictureCacheBytesSorted = List<int>.from(pictureCacheBytes)
      ..sort();
    final List<Duration> vsyncOverheadSorted =
        List<Duration>.from(vsyncOverhead)..sort();
    Duration add(Duration a, Duration b) => a + b;
    int addInts(int a, int b) => a + b;
    return FrameTimingSummarizer._(
      frameBuildTime: frameBuildTime,
      frameRasterizerTime: frameRasterizerTime,
      vsyncOverhead: vsyncOverhead,
      // This average calculation is microsecond precision, which is fine
      // because typical values of these times are milliseconds.
      averageFrameBuildTime: frameBuildTime.reduce(add) ~/ data.length,
      p90FrameBuildTime: _findPercentile(frameBuildTimeSorted, 0.90),
      p99FrameBuildTime: _findPercentile(frameBuildTimeSorted, 0.99),
      worstFrameBuildTime: frameBuildTimeSorted.last,
      missedFrameBuildBudget: _countExceed(frameBuildTimeSorted, kBuildBudget),
      averageFrameRasterizerTime:
          frameRasterizerTime.reduce(add) ~/ data.length,
      p90FrameRasterizerTime: _findPercentile(frameRasterizerTimeSorted, 0.90),
      p99FrameRasterizerTime: _findPercentile(frameRasterizerTimeSorted, 0.99),
      worstFrameRasterizerTime: frameRasterizerTimeSorted.last,
      averageLayerCacheCount: layerCacheCounts.reduce(addInts) / data.length,
      p90LayerCacheCount: _findPercentile(layerCacheCountsSorted, 0.90),
      p99LayerCacheCount: _findPercentile(layerCacheCountsSorted, 0.99),
      worstLayerCacheCount: layerCacheCountsSorted.last,
      averageLayerCacheBytes: layerCacheBytes.reduce(addInts) / data.length,
      p90LayerCacheBytes: _findPercentile(layerCacheBytesSorted, 0.90),
      p99LayerCacheBytes: _findPercentile(layerCacheBytesSorted, 0.99),
      worstLayerCacheBytes: layerCacheBytesSorted.last,
      averagePictureCacheCount:
          pictureCacheCounts.reduce(addInts) / data.length,
      p90PictureCacheCount: _findPercentile(pictureCacheCountsSorted, 0.90),
      p99PictureCacheCount: _findPercentile(pictureCacheCountsSorted, 0.99),
      worstPictureCacheCount: pictureCacheCountsSorted.last,
      averagePictureCacheBytes: pictureCacheBytes.reduce(addInts) / data.length,
      p90PictureCacheBytes: _findPercentile(pictureCacheBytesSorted, 0.90),
      p99PictureCacheBytes: _findPercentile(pictureCacheBytesSorted, 0.99),
      worstPictureCacheBytes: pictureCacheBytesSorted.last,
      missedFrameRasterizerBudget:
          _countExceed(frameRasterizerTimeSorted, kBuildBudget),
      averageVsyncOverhead: vsyncOverhead.reduce(add) ~/ data.length,
      p90VsyncOverhead: _findPercentile(vsyncOverheadSorted, 0.90),
      p99VsyncOverhead: _findPercentile(vsyncOverheadSorted, 0.99),
      worstVsyncOverhead: vsyncOverheadSorted.last,
      newGenGCCount: newGenGCCount ?? -1,
      oldGenGCCount: oldGenGCCount ?? -1,
    );
  }

  const FrameTimingSummarizer._({
    required this.frameBuildTime,
    required this.frameRasterizerTime,
    required this.averageFrameBuildTime,
    required this.p90FrameBuildTime,
    required this.p99FrameBuildTime,
    required this.worstFrameBuildTime,
    required this.missedFrameBuildBudget,
    required this.averageFrameRasterizerTime,
    required this.p90FrameRasterizerTime,
    required this.p99FrameRasterizerTime,
    required this.worstFrameRasterizerTime,
    required this.averageLayerCacheCount,
    required this.p90LayerCacheCount,
    required this.p99LayerCacheCount,
    required this.worstLayerCacheCount,
    required this.averageLayerCacheBytes,
    required this.p90LayerCacheBytes,
    required this.p99LayerCacheBytes,
    required this.worstLayerCacheBytes,
    required this.averagePictureCacheCount,
    required this.p90PictureCacheCount,
    required this.p99PictureCacheCount,
    required this.worstPictureCacheCount,
    required this.averagePictureCacheBytes,
    required this.p90PictureCacheBytes,
    required this.p99PictureCacheBytes,
    required this.worstPictureCacheBytes,
    required this.missedFrameRasterizerBudget,
    required this.vsyncOverhead,
    required this.averageVsyncOverhead,
    required this.p90VsyncOverhead,
    required this.p99VsyncOverhead,
    required this.worstVsyncOverhead,
    required this.newGenGCCount,
    required this.oldGenGCCount,
  });

  final List<Duration> frameBuildTime;

  final List<Duration> frameRasterizerTime;

  final List<Duration> vsyncOverhead;

  final Duration averageFrameBuildTime;

  final Duration p90FrameBuildTime;

  final Duration p99FrameBuildTime;

  final Duration worstFrameBuildTime;

  final int missedFrameBuildBudget;

  final Duration averageFrameRasterizerTime;

  final Duration p90FrameRasterizerTime;

  final Duration p99FrameRasterizerTime;

  final Duration worstFrameRasterizerTime;

  final double averageLayerCacheCount;

  final int p90LayerCacheCount;

  final int p99LayerCacheCount;

  final int worstLayerCacheCount;

  final double averageLayerCacheBytes;

  final int p90LayerCacheBytes;

  final int p99LayerCacheBytes;

  final int worstLayerCacheBytes;

  final double averagePictureCacheCount;

  final int p90PictureCacheCount;

  final int p99PictureCacheCount;

  final int worstPictureCacheCount;

  final double averagePictureCacheBytes;

  final int p90PictureCacheBytes;

  final int p99PictureCacheBytes;

  final int worstPictureCacheBytes;

  final int missedFrameRasterizerBudget;

  final Duration averageVsyncOverhead;

  final Duration p90VsyncOverhead;

  final Duration p99VsyncOverhead;

  final Duration worstVsyncOverhead;

  final int newGenGCCount;

  final int oldGenGCCount;

  Map<String, dynamic> get summary => <String, dynamic>{
        'average_frame_build_time_millis':
            averageFrameBuildTime.inMicroseconds / 1E3,
        '90th_percentile_frame_build_time_millis':
            p90FrameBuildTime.inMicroseconds / 1E3,
        '99th_percentile_frame_build_time_millis':
            p99FrameBuildTime.inMicroseconds / 1E3,
        'worst_frame_build_time_millis':
            worstFrameBuildTime.inMicroseconds / 1E3,
        'missed_frame_build_budget_count': missedFrameBuildBudget,
        'average_frame_rasterizer_time_millis':
            averageFrameRasterizerTime.inMicroseconds / 1E3,
        '90th_percentile_frame_rasterizer_time_millis':
            p90FrameRasterizerTime.inMicroseconds / 1E3,
        '99th_percentile_frame_rasterizer_time_millis':
            p99FrameRasterizerTime.inMicroseconds / 1E3,
        'worst_frame_rasterizer_time_millis':
            worstFrameRasterizerTime.inMicroseconds / 1E3,
        'average_layer_cache_count': averageLayerCacheCount,
        '90th_percentile_layer_cache_count': p90LayerCacheCount,
        '99th_percentile_layer_cache_count': p99LayerCacheCount,
        'worst_layer_cache_count': worstLayerCacheCount,
        'average_layer_cache_memory': averageLayerCacheBytes / 1024.0 / 1024.0,
        '90th_percentile_layer_cache_memory':
            p90LayerCacheBytes / 1024.0 / 1024.0,
        '99th_percentile_layer_cache_memory':
            p99LayerCacheBytes / 1024.0 / 1024.0,
        'worst_layer_cache_memory': worstLayerCacheBytes / 1024.0 / 1024.0,
        'average_picture_cache_count': averagePictureCacheCount,
        '90th_percentile_picture_cache_count': p90PictureCacheCount,
        '99th_percentile_picture_cache_count': p99PictureCacheCount,
        'worst_picture_cache_count': worstPictureCacheCount,
        'average_picture_cache_memory':
            averagePictureCacheBytes / 1024.0 / 1024.0,
        '90th_percentile_picture_cache_memory':
            p90PictureCacheBytes / 1024.0 / 1024.0,
        '99th_percentile_picture_cache_memory':
            p99PictureCacheBytes / 1024.0 / 1024.0,
        'worst_picture_cache_memory': worstPictureCacheBytes / 1024.0 / 1024.0,
        'missed_frame_rasterizer_budget_count': missedFrameRasterizerBudget,
        'frame_count': frameBuildTime.length,
        'frame_build_times': frameBuildTime
            .map<int>((Duration datum) => datum.inMicroseconds)
            .toList(),
        'frame_rasterizer_times': frameRasterizerTime
            .map<int>((Duration datum) => datum.inMicroseconds)
            .toList(),
        'new_gen_gc_count': newGenGCCount,
        'old_gen_gc_count': oldGenGCCount,
      };
}

T _findPercentile<T>(List<T> data, double p) {
  assert(p >= 0 && p <= 1);
  return data[((data.length - 1) * p).round()];
}

int _countExceed<T extends Comparable<T>>(List<T> data, T threshold) {
  final int exceedsThresholdIndex =
      data.indexWhere((T datum) => datum.compareTo(threshold) > 0);
  if (exceedsThresholdIndex == -1) {
    return 0;
  }
  return data.length - exceedsThresholdIndex;
}
