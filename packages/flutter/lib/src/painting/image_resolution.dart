
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'image_provider.dart';

const double _kLowDprLimit = 2.0;

@immutable
class AssetImage extends AssetBundleImageProvider {
  const AssetImage(
    this.assetName, {
    this.bundle,
    this.package,
  });

  final String assetName;

  String get keyName => package == null ? assetName : 'packages/$package/$assetName';

  final AssetBundle? bundle;

  final String? package;

  // We assume the main asset is designed for a device pixel ratio of 1.0
  static const double _naturalResolution = 1.0;

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    // This function tries to return a SynchronousFuture if possible. We do this
    // because otherwise showing an image would always take at least one frame,
    // which would be sad. (This code is called from inside build/layout/paint,
    // which all happens in one call frame; using native Futures would guarantee
    // that we resolve each future in a new call frame, and thus not in this
    // build/layout/paint sequence.)
    final AssetBundle chosenBundle = bundle ?? configuration.bundle ?? rootBundle;
    Completer<AssetBundleImageKey>? completer;
    Future<AssetBundleImageKey>? result;

    AssetManifest.loadFromAssetBundle(chosenBundle)
      .then((AssetManifest manifest) {
        final Iterable<AssetMetadata>? candidateVariants = manifest.getAssetVariants(keyName);
        final AssetMetadata chosenVariant = _chooseVariant(
          keyName,
          configuration,
          candidateVariants,
        );
        final AssetBundleImageKey key = AssetBundleImageKey(
          bundle: chosenBundle,
          name: chosenVariant.key,
          scale: chosenVariant.targetDevicePixelRatio ?? _naturalResolution,
        );
        if (completer != null) {
          // We already returned from this function, which means we are in the
          // asynchronous mode. Pass the value to the completer. The completer's
          // future is what we returned.
          completer.complete(key);
        } else {
          // We haven't yet returned, so we must have been called synchronously
          // just after loadStructuredData returned (which means it provided us
          // with a SynchronousFuture). Let's return a SynchronousFuture
          // ourselves.
          result = SynchronousFuture<AssetBundleImageKey>(key);
        }
      })
      .onError((Object error, StackTrace stack) {
        // We had an error. (This guarantees we weren't called synchronously.)
        // Forward the error to the caller.
        assert(completer != null);
        assert(result == null);
        completer!.completeError(error, stack);
      });

    if (result != null) {
      // The code above ran synchronously, and came up with an answer.
      // Return the SynchronousFuture that we created above.
      return result!;
    }
    // The code above hasn't yet run its "then" handler yet. Let's prepare a
    // completer for it to use when it does run.
    completer = Completer<AssetBundleImageKey>();
    return completer.future;
  }

  AssetMetadata _chooseVariant(String mainAssetKey, ImageConfiguration config, Iterable<AssetMetadata>? candidateVariants) {
    if (candidateVariants == null || candidateVariants.isEmpty || config.devicePixelRatio == null) {
      return AssetMetadata(key: mainAssetKey, targetDevicePixelRatio: null, main: true);
    }

    final SplayTreeMap<double, AssetMetadata> candidatesByDevicePixelRatio =
      SplayTreeMap<double, AssetMetadata>();
    for (final AssetMetadata candidate in candidateVariants) {
      candidatesByDevicePixelRatio[candidate.targetDevicePixelRatio ?? _naturalResolution] = candidate;
    }
    // TODO(ianh): implement support for config.locale, config.textDirection,
    // config.size, config.platform (then document this over in the Image.asset
    // docs)
    return _findBestVariant(candidatesByDevicePixelRatio, config.devicePixelRatio!);
  }

  // Returns the "best" asset variant amongst the available `candidates`.
  //
  // The best variant is chosen as follows:
  // - Choose a variant whose key matches `value` exactly, if available.
  // - If `value` is less than the lowest key, choose the variant with the
  //   lowest key.
  // - If `value` is greater than the highest key, choose the variant with
  //   the highest key.
  // - If the screen has low device pixel ratio, choose the variant with the
  //   lowest key higher than `value`.
  // - If the screen has high device pixel ratio, choose the variant with the
  //   key nearest to `value`.
  AssetMetadata _findBestVariant(SplayTreeMap<double, AssetMetadata> candidatesByDpr, double value) {
    if (candidatesByDpr.containsKey(value)) {
      return candidatesByDpr[value]!;
    }
    final double? lower = candidatesByDpr.lastKeyBefore(value);
    final double? upper = candidatesByDpr.firstKeyAfter(value);
    if (lower == null) {
      return candidatesByDpr[upper]!;
    }
    if (upper == null) {
      return candidatesByDpr[lower]!;
    }

    // On screens with low device-pixel ratios the artifacts from upscaling
    // images are more visible than on screens with a higher device-pixel
    // ratios because the physical pixels are larger. Choose the higher
    // resolution image in that case instead of the nearest one.
    if (value < _kLowDprLimit || value > (lower + upper) / 2) {
      return candidatesByDpr[upper]!;
    } else {
      return candidatesByDpr[lower]!;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is AssetImage
        && other.keyName == keyName
        && other.bundle == bundle;
  }

  @override
  int get hashCode => Object.hash(keyName, bundle);

  @override
  String toString() => '${objectRuntimeType(this, 'AssetImage')}(bundle: $bundle, name: "$keyName")';
}