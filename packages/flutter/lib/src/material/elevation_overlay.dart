import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'theme.dart';

abstract final class ElevationOverlay {
  static Color applySurfaceTint(Color color, Color? surfaceTint, double elevation) {
    if (surfaceTint != null && surfaceTint != Colors.transparent) {
      return Color.alphaBlend(surfaceTint.withOpacity(_surfaceTintOpacityForElevation(elevation)), color);
    }
    return color;
  }

  // Calculates the opacity of the surface tint color from the elevation by
  // looking it up in the token generated table of opacities, interpolating
  // between values as needed. If the elevation is outside the range of values
  // in the table it will clamp to the smallest or largest opacity.
  static double _surfaceTintOpacityForElevation(double elevation) {
    if (elevation < _surfaceTintElevationOpacities[0].elevation) {
      // Elevation less than the first entry, so just clamp it to the first one.
      return _surfaceTintElevationOpacities[0].opacity;
    }

    // Walk the opacity list and find the closest match(es) for the elevation.
    int index = 0;
    while (elevation >= _surfaceTintElevationOpacities[index].elevation) {
      // If we found it exactly or walked off the end of the list just return it.
      if (elevation == _surfaceTintElevationOpacities[index].elevation ||
          index + 1 == _surfaceTintElevationOpacities.length) {
        return _surfaceTintElevationOpacities[index].opacity;
      }
      index += 1;
    }

    // Interpolate between the two opacity values
    final _ElevationOpacity lower = _surfaceTintElevationOpacities[index - 1];
    final _ElevationOpacity upper = _surfaceTintElevationOpacities[index];
    final double t = (elevation - lower.elevation) / (upper.elevation - lower.elevation);
    return lower.opacity + t * (upper.opacity - lower.opacity);
  }

  static Color applyOverlay(BuildContext context, Color color, double elevation) {
    final ThemeData theme = Theme.of(context);
    if (elevation > 0.0 &&
        theme.applyElevationOverlayColor &&
        theme.brightness == Brightness.dark &&
        color.withOpacity(1.0) == theme.colorScheme.surface.withOpacity(1.0)) {
      return colorWithOverlay(color, theme.colorScheme.onSurface, elevation);
    }
    return color;
  }

  static Color overlayColor(BuildContext context, double elevation) {
    final ThemeData theme = Theme.of(context);
    return _overlayColor(theme.colorScheme.onSurface, elevation);
  }

  static Color colorWithOverlay(Color surface, Color overlay, double elevation) {
    return Color.alphaBlend(_overlayColor(overlay, elevation), surface);
  }

  static Color _overlayColor(Color color, double elevation) {
    // Compute the opacity for the given elevation
    // This formula matches the values in the spec:
    // https://material.io/design/color/dark-theme.html#properties
    final double opacity = (4.5 * math.log(elevation + 1) + 2) / 100.0;
    return color.withOpacity(opacity);
  }
}

// A data class to hold the opacity at a given elevation.
class _ElevationOpacity {
  const _ElevationOpacity(this.elevation, this.opacity);

  final double elevation;
  final double opacity;
}

// BEGIN GENERATED TOKEN PROPERTIES - SurfaceTint

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

// Surface tint opacities based on elevations according to the
// Material Design 3 specification:
//   https://m3.material.io/styles/color/the-color-system/color-roles
// Ordered by increasing elevation.
const List<_ElevationOpacity> _surfaceTintElevationOpacities = <_ElevationOpacity>[
  _ElevationOpacity(0.0, 0.0),   // Elevation level 0
  _ElevationOpacity(1.0, 0.05),  // Elevation level 1
  _ElevationOpacity(3.0, 0.08),  // Elevation level 2
  _ElevationOpacity(6.0, 0.11),  // Elevation level 3
  _ElevationOpacity(8.0, 0.12),  // Elevation level 4
  _ElevationOpacity(12.0, 0.14), // Elevation level 5
];

// END GENERATED TOKEN PROPERTIES - SurfaceTint