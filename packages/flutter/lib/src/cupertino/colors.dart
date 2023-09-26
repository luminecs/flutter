import 'dart:ui' show Brightness, Color;

import '../../foundation.dart';
import '../widgets/basic.dart';
import '../widgets/framework.dart';
import '../widgets/media_query.dart';
import 'interface_level.dart';
import 'theme.dart';

// Examples can assume:
// late Widget child;
// late BuildContext context;

abstract final class CupertinoColors {
  static const CupertinoDynamicColor activeBlue = systemBlue;

  static const CupertinoDynamicColor activeGreen = systemGreen;

  static const CupertinoDynamicColor activeOrange = systemOrange;

  static const Color white = Color(0xFFFFFFFF);

  static const Color black = Color(0xFF000000);

  static const Color lightBackgroundGray = Color(0xFFE5E5EA);

  static const Color extraLightBackgroundGray = Color(0xFFEFEFF4);

  // Value derived from screenshot from the dark themed Apple Watch app.
  static const Color darkBackgroundGray = Color(0xFF171717);

  static const CupertinoDynamicColor inactiveGray =
      CupertinoDynamicColor.withBrightness(
    debugLabel: 'inactiveGray',
    color: Color(0xFF999999),
    darkColor: Color(0xFF757575),
  );

  static const Color destructiveRed = systemRed;

  static const CupertinoDynamicColor systemBlue =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemBlue',
    color: Color.fromARGB(255, 0, 122, 255),
    darkColor: Color.fromARGB(255, 10, 132, 255),
    highContrastColor: Color.fromARGB(255, 0, 64, 221),
    darkHighContrastColor: Color.fromARGB(255, 64, 156, 255),
  );

  static const CupertinoDynamicColor systemGreen =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemGreen',
    color: Color.fromARGB(255, 52, 199, 89),
    darkColor: Color.fromARGB(255, 48, 209, 88),
    highContrastColor: Color.fromARGB(255, 36, 138, 61),
    darkHighContrastColor: Color.fromARGB(255, 48, 219, 91),
  );

  static const CupertinoDynamicColor systemMint =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemMint',
    color: Color.fromARGB(255, 0, 199, 190),
    darkColor: Color.fromARGB(255, 99, 230, 226),
    highContrastColor: Color.fromARGB(255, 12, 129, 123),
    darkHighContrastColor: Color.fromARGB(255, 102, 212, 207),
  );

  static const CupertinoDynamicColor systemIndigo =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemIndigo',
    color: Color.fromARGB(255, 88, 86, 214),
    darkColor: Color.fromARGB(255, 94, 92, 230),
    highContrastColor: Color.fromARGB(255, 54, 52, 163),
    darkHighContrastColor: Color.fromARGB(255, 125, 122, 255),
  );

  static const CupertinoDynamicColor systemOrange =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemOrange',
    color: Color.fromARGB(255, 255, 149, 0),
    darkColor: Color.fromARGB(255, 255, 159, 10),
    highContrastColor: Color.fromARGB(255, 201, 52, 0),
    darkHighContrastColor: Color.fromARGB(255, 255, 179, 64),
  );

  static const CupertinoDynamicColor systemPink =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemPink',
    color: Color.fromARGB(255, 255, 45, 85),
    darkColor: Color.fromARGB(255, 255, 55, 95),
    highContrastColor: Color.fromARGB(255, 211, 15, 69),
    darkHighContrastColor: Color.fromARGB(255, 255, 100, 130),
  );

  static const CupertinoDynamicColor systemBrown =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemBrown',
    color: Color.fromARGB(255, 162, 132, 94),
    darkColor: Color.fromARGB(255, 172, 142, 104),
    highContrastColor: Color.fromARGB(255, 127, 101, 69),
    darkHighContrastColor: Color.fromARGB(255, 181, 148, 105),
  );

  static const CupertinoDynamicColor systemPurple =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemPurple',
    color: Color.fromARGB(255, 175, 82, 222),
    darkColor: Color.fromARGB(255, 191, 90, 242),
    highContrastColor: Color.fromARGB(255, 137, 68, 171),
    darkHighContrastColor: Color.fromARGB(255, 218, 143, 255),
  );

  static const CupertinoDynamicColor systemRed =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemRed',
    color: Color.fromARGB(255, 255, 59, 48),
    darkColor: Color.fromARGB(255, 255, 69, 58),
    highContrastColor: Color.fromARGB(255, 215, 0, 21),
    darkHighContrastColor: Color.fromARGB(255, 255, 105, 97),
  );

  static const CupertinoDynamicColor systemTeal =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemTeal',
    color: Color.fromARGB(255, 90, 200, 250),
    darkColor: Color.fromARGB(255, 100, 210, 255),
    highContrastColor: Color.fromARGB(255, 0, 113, 164),
    darkHighContrastColor: Color.fromARGB(255, 112, 215, 255),
  );

  static const CupertinoDynamicColor systemCyan =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemCyan',
    color: Color.fromARGB(255, 50, 173, 230),
    darkColor: Color.fromARGB(255, 100, 210, 255),
    highContrastColor: Color.fromARGB(255, 0, 113, 164),
    darkHighContrastColor: Color.fromARGB(255, 112, 215, 255),
  );

  static const CupertinoDynamicColor systemYellow =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemYellow',
    color: Color.fromARGB(255, 255, 204, 0),
    darkColor: Color.fromARGB(255, 255, 214, 10),
    highContrastColor: Color.fromARGB(255, 160, 90, 0),
    darkHighContrastColor: Color.fromARGB(255, 255, 212, 38),
  );

  static const CupertinoDynamicColor systemGrey =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemGrey',
    color: Color.fromARGB(255, 142, 142, 147),
    darkColor: Color.fromARGB(255, 142, 142, 147),
    highContrastColor: Color.fromARGB(255, 108, 108, 112),
    darkHighContrastColor: Color.fromARGB(255, 174, 174, 178),
  );

  static const CupertinoDynamicColor systemGrey2 =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemGrey2',
    color: Color.fromARGB(255, 174, 174, 178),
    darkColor: Color.fromARGB(255, 99, 99, 102),
    highContrastColor: Color.fromARGB(255, 142, 142, 147),
    darkHighContrastColor: Color.fromARGB(255, 124, 124, 128),
  );

  static const CupertinoDynamicColor systemGrey3 =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemGrey3',
    color: Color.fromARGB(255, 199, 199, 204),
    darkColor: Color.fromARGB(255, 72, 72, 74),
    highContrastColor: Color.fromARGB(255, 174, 174, 178),
    darkHighContrastColor: Color.fromARGB(255, 84, 84, 86),
  );

  static const CupertinoDynamicColor systemGrey4 =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemGrey4',
    color: Color.fromARGB(255, 209, 209, 214),
    darkColor: Color.fromARGB(255, 58, 58, 60),
    highContrastColor: Color.fromARGB(255, 188, 188, 192),
    darkHighContrastColor: Color.fromARGB(255, 68, 68, 70),
  );

  static const CupertinoDynamicColor systemGrey5 =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemGrey5',
    color: Color.fromARGB(255, 229, 229, 234),
    darkColor: Color.fromARGB(255, 44, 44, 46),
    highContrastColor: Color.fromARGB(255, 216, 216, 220),
    darkHighContrastColor: Color.fromARGB(255, 54, 54, 56),
  );

  static const CupertinoDynamicColor systemGrey6 =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'systemGrey6',
    color: Color.fromARGB(255, 242, 242, 247),
    darkColor: Color.fromARGB(255, 28, 28, 30),
    highContrastColor: Color.fromARGB(255, 235, 235, 240),
    darkHighContrastColor: Color.fromARGB(255, 36, 36, 38),
  );

  static const CupertinoDynamicColor label = CupertinoDynamicColor(
    debugLabel: 'label',
    color: Color.fromARGB(255, 0, 0, 0),
    darkColor: Color.fromARGB(255, 255, 255, 255),
    highContrastColor: Color.fromARGB(255, 0, 0, 0),
    darkHighContrastColor: Color.fromARGB(255, 255, 255, 255),
    elevatedColor: Color.fromARGB(255, 0, 0, 0),
    darkElevatedColor: Color.fromARGB(255, 255, 255, 255),
    highContrastElevatedColor: Color.fromARGB(255, 0, 0, 0),
    darkHighContrastElevatedColor: Color.fromARGB(255, 255, 255, 255),
  );

  static const CupertinoDynamicColor secondaryLabel = CupertinoDynamicColor(
    debugLabel: 'secondaryLabel',
    color: Color.fromARGB(153, 60, 60, 67),
    darkColor: Color.fromARGB(153, 235, 235, 245),
    highContrastColor: Color.fromARGB(173, 60, 60, 67),
    darkHighContrastColor: Color.fromARGB(173, 235, 235, 245),
    elevatedColor: Color.fromARGB(153, 60, 60, 67),
    darkElevatedColor: Color.fromARGB(153, 235, 235, 245),
    highContrastElevatedColor: Color.fromARGB(173, 60, 60, 67),
    darkHighContrastElevatedColor: Color.fromARGB(173, 235, 235, 245),
  );

  static const CupertinoDynamicColor tertiaryLabel = CupertinoDynamicColor(
    debugLabel: 'tertiaryLabel',
    color: Color.fromARGB(76, 60, 60, 67),
    darkColor: Color.fromARGB(76, 235, 235, 245),
    highContrastColor: Color.fromARGB(96, 60, 60, 67),
    darkHighContrastColor: Color.fromARGB(96, 235, 235, 245),
    elevatedColor: Color.fromARGB(76, 60, 60, 67),
    darkElevatedColor: Color.fromARGB(76, 235, 235, 245),
    highContrastElevatedColor: Color.fromARGB(96, 60, 60, 67),
    darkHighContrastElevatedColor: Color.fromARGB(96, 235, 235, 245),
  );

  static const CupertinoDynamicColor quaternaryLabel = CupertinoDynamicColor(
    debugLabel: 'quaternaryLabel',
    color: Color.fromARGB(45, 60, 60, 67),
    darkColor: Color.fromARGB(40, 235, 235, 245),
    highContrastColor: Color.fromARGB(66, 60, 60, 67),
    darkHighContrastColor: Color.fromARGB(61, 235, 235, 245),
    elevatedColor: Color.fromARGB(45, 60, 60, 67),
    darkElevatedColor: Color.fromARGB(40, 235, 235, 245),
    highContrastElevatedColor: Color.fromARGB(66, 60, 60, 67),
    darkHighContrastElevatedColor: Color.fromARGB(61, 235, 235, 245),
  );

  static const CupertinoDynamicColor systemFill = CupertinoDynamicColor(
    debugLabel: 'systemFill',
    color: Color.fromARGB(51, 120, 120, 128),
    darkColor: Color.fromARGB(91, 120, 120, 128),
    highContrastColor: Color.fromARGB(71, 120, 120, 128),
    darkHighContrastColor: Color.fromARGB(112, 120, 120, 128),
    elevatedColor: Color.fromARGB(51, 120, 120, 128),
    darkElevatedColor: Color.fromARGB(91, 120, 120, 128),
    highContrastElevatedColor: Color.fromARGB(71, 120, 120, 128),
    darkHighContrastElevatedColor: Color.fromARGB(112, 120, 120, 128),
  );

  static const CupertinoDynamicColor secondarySystemFill =
      CupertinoDynamicColor(
    debugLabel: 'secondarySystemFill',
    color: Color.fromARGB(40, 120, 120, 128),
    darkColor: Color.fromARGB(81, 120, 120, 128),
    highContrastColor: Color.fromARGB(61, 120, 120, 128),
    darkHighContrastColor: Color.fromARGB(102, 120, 120, 128),
    elevatedColor: Color.fromARGB(40, 120, 120, 128),
    darkElevatedColor: Color.fromARGB(81, 120, 120, 128),
    highContrastElevatedColor: Color.fromARGB(61, 120, 120, 128),
    darkHighContrastElevatedColor: Color.fromARGB(102, 120, 120, 128),
  );

  static const CupertinoDynamicColor tertiarySystemFill = CupertinoDynamicColor(
    debugLabel: 'tertiarySystemFill',
    color: Color.fromARGB(30, 118, 118, 128),
    darkColor: Color.fromARGB(61, 118, 118, 128),
    highContrastColor: Color.fromARGB(51, 118, 118, 128),
    darkHighContrastColor: Color.fromARGB(81, 118, 118, 128),
    elevatedColor: Color.fromARGB(30, 118, 118, 128),
    darkElevatedColor: Color.fromARGB(61, 118, 118, 128),
    highContrastElevatedColor: Color.fromARGB(51, 118, 118, 128),
    darkHighContrastElevatedColor: Color.fromARGB(81, 118, 118, 128),
  );

  static const CupertinoDynamicColor quaternarySystemFill =
      CupertinoDynamicColor(
    debugLabel: 'quaternarySystemFill',
    color: Color.fromARGB(20, 116, 116, 128),
    darkColor: Color.fromARGB(45, 118, 118, 128),
    highContrastColor: Color.fromARGB(40, 116, 116, 128),
    darkHighContrastColor: Color.fromARGB(66, 118, 118, 128),
    elevatedColor: Color.fromARGB(20, 116, 116, 128),
    darkElevatedColor: Color.fromARGB(45, 118, 118, 128),
    highContrastElevatedColor: Color.fromARGB(40, 116, 116, 128),
    darkHighContrastElevatedColor: Color.fromARGB(66, 118, 118, 128),
  );

  static const CupertinoDynamicColor placeholderText = CupertinoDynamicColor(
    debugLabel: 'placeholderText',
    color: Color.fromARGB(76, 60, 60, 67),
    darkColor: Color.fromARGB(76, 235, 235, 245),
    highContrastColor: Color.fromARGB(96, 60, 60, 67),
    darkHighContrastColor: Color.fromARGB(96, 235, 235, 245),
    elevatedColor: Color.fromARGB(76, 60, 60, 67),
    darkElevatedColor: Color.fromARGB(76, 235, 235, 245),
    highContrastElevatedColor: Color.fromARGB(96, 60, 60, 67),
    darkHighContrastElevatedColor: Color.fromARGB(96, 235, 235, 245),
  );

  static const CupertinoDynamicColor systemBackground = CupertinoDynamicColor(
    debugLabel: 'systemBackground',
    color: Color.fromARGB(255, 255, 255, 255),
    darkColor: Color.fromARGB(255, 0, 0, 0),
    highContrastColor: Color.fromARGB(255, 255, 255, 255),
    darkHighContrastColor: Color.fromARGB(255, 0, 0, 0),
    elevatedColor: Color.fromARGB(255, 255, 255, 255),
    darkElevatedColor: Color.fromARGB(255, 28, 28, 30),
    highContrastElevatedColor: Color.fromARGB(255, 255, 255, 255),
    darkHighContrastElevatedColor: Color.fromARGB(255, 36, 36, 38),
  );

  static const CupertinoDynamicColor secondarySystemBackground =
      CupertinoDynamicColor(
    debugLabel: 'secondarySystemBackground',
    color: Color.fromARGB(255, 242, 242, 247),
    darkColor: Color.fromARGB(255, 28, 28, 30),
    highContrastColor: Color.fromARGB(255, 235, 235, 240),
    darkHighContrastColor: Color.fromARGB(255, 36, 36, 38),
    elevatedColor: Color.fromARGB(255, 242, 242, 247),
    darkElevatedColor: Color.fromARGB(255, 44, 44, 46),
    highContrastElevatedColor: Color.fromARGB(255, 235, 235, 240),
    darkHighContrastElevatedColor: Color.fromARGB(255, 54, 54, 56),
  );

  static const CupertinoDynamicColor tertiarySystemBackground =
      CupertinoDynamicColor(
    debugLabel: 'tertiarySystemBackground',
    color: Color.fromARGB(255, 255, 255, 255),
    darkColor: Color.fromARGB(255, 44, 44, 46),
    highContrastColor: Color.fromARGB(255, 255, 255, 255),
    darkHighContrastColor: Color.fromARGB(255, 54, 54, 56),
    elevatedColor: Color.fromARGB(255, 255, 255, 255),
    darkElevatedColor: Color.fromARGB(255, 58, 58, 60),
    highContrastElevatedColor: Color.fromARGB(255, 255, 255, 255),
    darkHighContrastElevatedColor: Color.fromARGB(255, 68, 68, 70),
  );

  static const CupertinoDynamicColor systemGroupedBackground =
      CupertinoDynamicColor(
    debugLabel: 'systemGroupedBackground',
    color: Color.fromARGB(255, 242, 242, 247),
    darkColor: Color.fromARGB(255, 0, 0, 0),
    highContrastColor: Color.fromARGB(255, 235, 235, 240),
    darkHighContrastColor: Color.fromARGB(255, 0, 0, 0),
    elevatedColor: Color.fromARGB(255, 242, 242, 247),
    darkElevatedColor: Color.fromARGB(255, 28, 28, 30),
    highContrastElevatedColor: Color.fromARGB(255, 235, 235, 240),
    darkHighContrastElevatedColor: Color.fromARGB(255, 36, 36, 38),
  );

  static const CupertinoDynamicColor secondarySystemGroupedBackground =
      CupertinoDynamicColor(
    debugLabel: 'secondarySystemGroupedBackground',
    color: Color.fromARGB(255, 255, 255, 255),
    darkColor: Color.fromARGB(255, 28, 28, 30),
    highContrastColor: Color.fromARGB(255, 255, 255, 255),
    darkHighContrastColor: Color.fromARGB(255, 36, 36, 38),
    elevatedColor: Color.fromARGB(255, 255, 255, 255),
    darkElevatedColor: Color.fromARGB(255, 44, 44, 46),
    highContrastElevatedColor: Color.fromARGB(255, 255, 255, 255),
    darkHighContrastElevatedColor: Color.fromARGB(255, 54, 54, 56),
  );

  static const CupertinoDynamicColor tertiarySystemGroupedBackground =
      CupertinoDynamicColor(
    debugLabel: 'tertiarySystemGroupedBackground',
    color: Color.fromARGB(255, 242, 242, 247),
    darkColor: Color.fromARGB(255, 44, 44, 46),
    highContrastColor: Color.fromARGB(255, 235, 235, 240),
    darkHighContrastColor: Color.fromARGB(255, 54, 54, 56),
    elevatedColor: Color.fromARGB(255, 242, 242, 247),
    darkElevatedColor: Color.fromARGB(255, 58, 58, 60),
    highContrastElevatedColor: Color.fromARGB(255, 235, 235, 240),
    darkHighContrastElevatedColor: Color.fromARGB(255, 68, 68, 70),
  );

  static const CupertinoDynamicColor separator = CupertinoDynamicColor(
    debugLabel: 'separator',
    color: Color.fromARGB(73, 60, 60, 67),
    darkColor: Color.fromARGB(153, 84, 84, 88),
    highContrastColor: Color.fromARGB(94, 60, 60, 67),
    darkHighContrastColor: Color.fromARGB(173, 84, 84, 88),
    elevatedColor: Color.fromARGB(73, 60, 60, 67),
    darkElevatedColor: Color.fromARGB(153, 84, 84, 88),
    highContrastElevatedColor: Color.fromARGB(94, 60, 60, 67),
    darkHighContrastElevatedColor: Color.fromARGB(173, 84, 84, 88),
  );

  static const CupertinoDynamicColor opaqueSeparator = CupertinoDynamicColor(
    debugLabel: 'opaqueSeparator',
    color: Color.fromARGB(255, 198, 198, 200),
    darkColor: Color.fromARGB(255, 56, 56, 58),
    highContrastColor: Color.fromARGB(255, 198, 198, 200),
    darkHighContrastColor: Color.fromARGB(255, 56, 56, 58),
    elevatedColor: Color.fromARGB(255, 198, 198, 200),
    darkElevatedColor: Color.fromARGB(255, 56, 56, 58),
    highContrastElevatedColor: Color.fromARGB(255, 198, 198, 200),
    darkHighContrastElevatedColor: Color.fromARGB(255, 56, 56, 58),
  );

  static const CupertinoDynamicColor link = CupertinoDynamicColor(
    debugLabel: 'link',
    color: Color.fromARGB(255, 0, 122, 255),
    darkColor: Color.fromARGB(255, 9, 132, 255),
    highContrastColor: Color.fromARGB(255, 0, 122, 255),
    darkHighContrastColor: Color.fromARGB(255, 9, 132, 255),
    elevatedColor: Color.fromARGB(255, 0, 122, 255),
    darkElevatedColor: Color.fromARGB(255, 9, 132, 255),
    highContrastElevatedColor: Color.fromARGB(255, 0, 122, 255),
    darkHighContrastElevatedColor: Color.fromARGB(255, 9, 132, 255),
  );
}

@immutable
class CupertinoDynamicColor extends Color with Diagnosticable {
  const CupertinoDynamicColor({
    String? debugLabel,
    required Color color,
    required Color darkColor,
    required Color highContrastColor,
    required Color darkHighContrastColor,
    required Color elevatedColor,
    required Color darkElevatedColor,
    required Color highContrastElevatedColor,
    required Color darkHighContrastElevatedColor,
  }) : this._(
          color,
          color,
          darkColor,
          highContrastColor,
          darkHighContrastColor,
          elevatedColor,
          darkElevatedColor,
          highContrastElevatedColor,
          darkHighContrastElevatedColor,
          null,
          debugLabel,
        );

  const CupertinoDynamicColor.withBrightnessAndContrast({
    String? debugLabel,
    required Color color,
    required Color darkColor,
    required Color highContrastColor,
    required Color darkHighContrastColor,
  }) : this(
          debugLabel: debugLabel,
          color: color,
          darkColor: darkColor,
          highContrastColor: highContrastColor,
          darkHighContrastColor: darkHighContrastColor,
          elevatedColor: color,
          darkElevatedColor: darkColor,
          highContrastElevatedColor: highContrastColor,
          darkHighContrastElevatedColor: darkHighContrastColor,
        );

  const CupertinoDynamicColor.withBrightness({
    String? debugLabel,
    required Color color,
    required Color darkColor,
  }) : this(
          debugLabel: debugLabel,
          color: color,
          darkColor: darkColor,
          highContrastColor: color,
          darkHighContrastColor: darkColor,
          elevatedColor: color,
          darkElevatedColor: darkColor,
          highContrastElevatedColor: color,
          darkHighContrastElevatedColor: darkColor,
        );

  const CupertinoDynamicColor._(
    this._effectiveColor,
    this.color,
    this.darkColor,
    this.highContrastColor,
    this.darkHighContrastColor,
    this.elevatedColor,
    this.darkElevatedColor,
    this.highContrastElevatedColor,
    this.darkHighContrastElevatedColor,
    this._debugResolveContext,
    this._debugLabel,
  ) : // The super constructor has to be called with a dummy value in order to mark
        // this constructor const.
        // The field `value` is overridden in the class implementation.
        super(0);

  final Color _effectiveColor;

  @override
  int get value => _effectiveColor.value;

  final String? _debugLabel;

  final Element? _debugResolveContext;

  final Color color;

  final Color darkColor;

  final Color highContrastColor;

  final Color darkHighContrastColor;

  final Color elevatedColor;

  final Color darkElevatedColor;

  final Color highContrastElevatedColor;

  final Color darkHighContrastElevatedColor;

  static Color resolve(Color resolvable, BuildContext context) {
    return (resolvable is CupertinoDynamicColor)
        ? resolvable.resolveFrom(context)
        : resolvable;
  }

  static Color? maybeResolve(Color? resolvable, BuildContext context) {
    if (resolvable == null) {
      return null;
    }
    return (resolvable is CupertinoDynamicColor)
        ? resolvable.resolveFrom(context)
        : resolvable;
  }

  bool get _isPlatformBrightnessDependent {
    return color != darkColor ||
        elevatedColor != darkElevatedColor ||
        highContrastColor != darkHighContrastColor ||
        highContrastElevatedColor != darkHighContrastElevatedColor;
  }

  bool get _isHighContrastDependent {
    return color != highContrastColor ||
        darkColor != darkHighContrastColor ||
        elevatedColor != highContrastElevatedColor ||
        darkElevatedColor != darkHighContrastElevatedColor;
  }

  bool get _isInterfaceElevationDependent {
    return color != elevatedColor ||
        darkColor != darkElevatedColor ||
        highContrastColor != highContrastElevatedColor ||
        darkHighContrastColor != darkHighContrastElevatedColor;
  }

  CupertinoDynamicColor resolveFrom(BuildContext context) {
    Brightness brightness = Brightness.light;
    if (_isPlatformBrightnessDependent) {
      brightness =
          CupertinoTheme.maybeBrightnessOf(context) ?? Brightness.light;
    }
    bool isHighContrastEnabled = false;
    if (_isHighContrastDependent) {
      isHighContrastEnabled = MediaQuery.maybeHighContrastOf(context) ?? false;
    }

    final CupertinoUserInterfaceLevelData level = _isInterfaceElevationDependent
        ? CupertinoUserInterfaceLevel.maybeOf(context) ??
            CupertinoUserInterfaceLevelData.base
        : CupertinoUserInterfaceLevelData.base;

    final Color resolved;
    switch (brightness) {
      case Brightness.light:
        switch (level) {
          case CupertinoUserInterfaceLevelData.base:
            resolved = isHighContrastEnabled ? highContrastColor : color;
          case CupertinoUserInterfaceLevelData.elevated:
            resolved = isHighContrastEnabled
                ? highContrastElevatedColor
                : elevatedColor;
        }
      case Brightness.dark:
        switch (level) {
          case CupertinoUserInterfaceLevelData.base:
            resolved =
                isHighContrastEnabled ? darkHighContrastColor : darkColor;
          case CupertinoUserInterfaceLevelData.elevated:
            resolved = isHighContrastEnabled
                ? darkHighContrastElevatedColor
                : darkElevatedColor;
        }
    }

    Element? debugContext;
    assert(() {
      debugContext = context as Element;
      return true;
    }());
    return CupertinoDynamicColor._(
      resolved,
      color,
      darkColor,
      highContrastColor,
      darkHighContrastColor,
      elevatedColor,
      darkElevatedColor,
      highContrastElevatedColor,
      darkHighContrastElevatedColor,
      debugContext,
      _debugLabel,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CupertinoDynamicColor &&
        other.value == value &&
        other.color == color &&
        other.darkColor == darkColor &&
        other.highContrastColor == highContrastColor &&
        other.darkHighContrastColor == darkHighContrastColor &&
        other.elevatedColor == elevatedColor &&
        other.darkElevatedColor == darkElevatedColor &&
        other.highContrastElevatedColor == highContrastElevatedColor &&
        other.darkHighContrastElevatedColor == darkHighContrastElevatedColor;
  }

  @override
  int get hashCode => Object.hash(
        value,
        color,
        darkColor,
        highContrastColor,
        elevatedColor,
        darkElevatedColor,
        darkHighContrastColor,
        darkHighContrastElevatedColor,
        highContrastElevatedColor,
      );

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    String toString(String name, Color color) {
      final String marker = color == _effectiveColor ? '*' : '';
      return '$marker$name = $color$marker';
    }

    final List<String> xs = <String>[
      toString('color', color),
      if (_isPlatformBrightnessDependent) toString('darkColor', darkColor),
      if (_isHighContrastDependent)
        toString('highContrastColor', highContrastColor),
      if (_isPlatformBrightnessDependent && _isHighContrastDependent)
        toString('darkHighContrastColor', darkHighContrastColor),
      if (_isInterfaceElevationDependent)
        toString('elevatedColor', elevatedColor),
      if (_isPlatformBrightnessDependent && _isInterfaceElevationDependent)
        toString('darkElevatedColor', darkElevatedColor),
      if (_isHighContrastDependent && _isInterfaceElevationDependent)
        toString('highContrastElevatedColor', highContrastElevatedColor),
      if (_isPlatformBrightnessDependent &&
          _isHighContrastDependent &&
          _isInterfaceElevationDependent)
        toString(
            'darkHighContrastElevatedColor', darkHighContrastElevatedColor),
    ];

    return '${_debugLabel ?? objectRuntimeType(this, 'CupertinoDynamicColor')}(${xs.join(', ')}, resolved by: ${_debugResolveContext?.widget ?? "UNRESOLVED"})';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    if (_debugLabel != null) {
      properties.add(MessageProperty('debugLabel', _debugLabel));
    }
    properties.add(createCupertinoColorProperty('color', color));
    if (_isPlatformBrightnessDependent) {
      properties.add(createCupertinoColorProperty('darkColor', darkColor));
    }
    if (_isHighContrastDependent) {
      properties.add(
          createCupertinoColorProperty('highContrastColor', highContrastColor));
    }
    if (_isPlatformBrightnessDependent && _isHighContrastDependent) {
      properties.add(createCupertinoColorProperty(
          'darkHighContrastColor', darkHighContrastColor));
    }
    if (_isInterfaceElevationDependent) {
      properties
          .add(createCupertinoColorProperty('elevatedColor', elevatedColor));
    }
    if (_isPlatformBrightnessDependent && _isInterfaceElevationDependent) {
      properties.add(
          createCupertinoColorProperty('darkElevatedColor', darkElevatedColor));
    }
    if (_isHighContrastDependent && _isInterfaceElevationDependent) {
      properties.add(createCupertinoColorProperty(
          'highContrastElevatedColor', highContrastElevatedColor));
    }
    if (_isPlatformBrightnessDependent &&
        _isHighContrastDependent &&
        _isInterfaceElevationDependent) {
      properties.add(createCupertinoColorProperty(
          'darkHighContrastElevatedColor', darkHighContrastElevatedColor));
    }

    if (_debugResolveContext != null) {
      properties.add(
          DiagnosticsProperty<Element>('last resolved', _debugResolveContext));
    }
  }
}

DiagnosticsProperty<Color> createCupertinoColorProperty(
  String name,
  Color? value, {
  bool showName = true,
  Object? defaultValue = kNoDefaultValue,
  DiagnosticsTreeStyle style = DiagnosticsTreeStyle.singleLine,
  DiagnosticLevel level = DiagnosticLevel.info,
}) {
  if (value is CupertinoDynamicColor) {
    return DiagnosticsProperty<CupertinoDynamicColor>(
      name,
      value,
      description: value._debugLabel,
      showName: showName,
      defaultValue: defaultValue,
      style: style,
      level: level,
    );
  } else {
    return ColorProperty(
      name,
      value,
      showName: showName,
      defaultValue: defaultValue,
      style: style,
      level: level,
    );
  }
}
