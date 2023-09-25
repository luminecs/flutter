// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'percentile_utils.dart';
import 'timeline.dart';

const String kRasterCacheEvent = 'RasterCache';

const String _kLayerCount = 'LayerCount';
const String _kLayerMemory = 'LayerMBytes';
const String _kPictureCount = 'PictureCount';
const String _kPictureMemory = 'PictureMBytes';

class RasterCacheSummarizer {
  RasterCacheSummarizer(this.rasterCacheEvents) {
    for (final TimelineEvent event in rasterCacheEvents) {
      assert(event.name == kRasterCacheEvent);
    }
  }

  final List<TimelineEvent> rasterCacheEvents;

  late final List<double> _layerCounts = _extractValues(_kLayerCount);
  late final List<double> _layerMemories = _extractValues(_kLayerMemory);
  late final List<double> _pictureCounts = _extractValues(_kPictureCount);
  late final List<double> _pictureMemories = _extractValues(_kPictureMemory);

  double computeAverageLayerCount() => _computeAverage(_layerCounts);

  double computeAverageLayerMemory() => _computeAverage(_layerMemories);

  double computeAveragePictureCount() => _computeAverage(_pictureCounts);

  double computeAveragePictureMemory() => _computeAverage(_pictureMemories);

  double computePercentileLayerCount(double percentile) => _computePercentile(_layerCounts, percentile);

  double computePercentileLayerMemory(double percentile) => _computePercentile(_layerMemories, percentile);

  double computePercentilePictureCount(double percentile) => _computePercentile(_pictureCounts, percentile);

  double computePercentilePictureMemory(double percentile) => _computePercentile(_pictureMemories, percentile);

  double computeWorstLayerCount() => _computeWorst(_layerCounts);

  double computeWorstLayerMemory() => _computeWorst(_layerMemories);

  double computeWorstPictureCount() => _computeWorst(_pictureCounts);

  double computeWorstPictureMemory() => _computeWorst(_pictureMemories);

  static double _computeAverage(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }

    final double total = values.reduce((double a, double b) => a + b);
    return total / values.length;
  }

  static double _computePercentile(List<double> values, double percentile) {
    if (values.isEmpty) {
      return 0;
    }

    return findPercentile(values, percentile);
  }

  static double _computeWorst(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }

    values.sort();
    return values.last;
  }

  List<double> _extractValues(String name) =>
      rasterCacheEvents.map((TimelineEvent e) => _getValue(e, name)).toList();

  double _getValue(TimelineEvent e, String name) {
    assert(e.name == kRasterCacheEvent);
    assert(e.arguments!.containsKey(name));
    final dynamic valueString = e.arguments![name];
    assert(valueString is String);
    return double.parse(valueString as String);
  }
}