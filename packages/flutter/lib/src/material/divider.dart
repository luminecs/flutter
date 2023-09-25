
import 'package:flutter/widgets.dart';

import 'divider_theme.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

class Divider extends StatelessWidget {
  const Divider({
    super.key,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  }) : assert(height == null || height >= 0.0),
       assert(thickness == null || thickness >= 0.0),
       assert(indent == null || indent >= 0.0),
       assert(endIndent == null || endIndent >= 0.0);


  final double? height;

  final double? thickness;

  final double? indent;

  final double? endIndent;

  final Color? color;

  static BorderSide createBorderSide(BuildContext? context, { Color? color, double? width }) {
    final DividerThemeData? dividerTheme = context != null ? DividerTheme.of(context) : null;
    final DividerThemeData? defaults = context != null
      ? Theme.of(context).useMaterial3 ? _DividerDefaultsM3(context) : _DividerDefaultsM2(context)
      : null;
    final Color? effectiveColor = color ?? dividerTheme?.color ?? defaults?.color;
    final double effectiveWidth =  width ?? dividerTheme?.thickness ?? defaults?.thickness ?? 0.0;

    // Prevent assertion since it is possible that context is null and no color
    // is specified.
    if (effectiveColor == null) {
      return BorderSide(
        width: effectiveWidth,
      );
    }
    return BorderSide(
      color: effectiveColor,
      width: effectiveWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DividerThemeData dividerTheme = DividerTheme.of(context);
    final DividerThemeData defaults = theme.useMaterial3 ? _DividerDefaultsM3(context) : _DividerDefaultsM2(context);
    final double height = this.height ?? dividerTheme.space ?? defaults.space!;
    final double thickness = this.thickness ?? dividerTheme.thickness ?? defaults.thickness!;
    final double indent = this.indent ?? dividerTheme.indent ?? defaults.indent!;
    final double endIndent = this.endIndent ?? dividerTheme.endIndent ?? defaults.endIndent!;

    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          height: thickness,
          margin: EdgeInsetsDirectional.only(start: indent, end: endIndent),
          decoration: BoxDecoration(
            border: Border(
              bottom: createBorderSide(context, color: color, width: thickness),
            ),
          ),
        ),
      ),
    );
  }
}

class VerticalDivider extends StatelessWidget {
  const VerticalDivider({
    super.key,
    this.width,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  }) : assert(width == null || width >= 0.0),
       assert(thickness == null || thickness >= 0.0),
       assert(indent == null || indent >= 0.0),
       assert(endIndent == null || endIndent >= 0.0);

  final double? width;

  final double? thickness;

  final double? indent;

  final double? endIndent;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DividerThemeData dividerTheme = DividerTheme.of(context);
    final DividerThemeData defaults = theme.useMaterial3 ? _DividerDefaultsM3(context) : _DividerDefaultsM2(context);
    final double width = this.width ?? dividerTheme.space ?? defaults.space!;
    final double thickness = this.thickness ?? dividerTheme.thickness ?? defaults.thickness!;
    final double indent = this.indent ?? dividerTheme.indent ?? defaults.indent!;
    final double endIndent = this.endIndent ?? dividerTheme.endIndent ?? defaults.endIndent!;

    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          width: thickness,
          margin: EdgeInsetsDirectional.only(top: indent, bottom: endIndent),
          decoration: BoxDecoration(
            border: Border(
              left: Divider.createBorderSide(context, color: color, width: thickness),
            ),
          ),
        ),
      ),
    );
  }
}

class _DividerDefaultsM2 extends DividerThemeData {
  const _DividerDefaultsM2(this.context) : super(
    space: 16,
    thickness: 0,
    indent: 0,
    endIndent: 0,
  );

  final BuildContext context;

  @override Color? get color => Theme.of(context).dividerColor;
}

// BEGIN GENERATED TOKEN PROPERTIES - Divider

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _DividerDefaultsM3 extends DividerThemeData {
  const _DividerDefaultsM3(this.context) : super(
    space: 16,
    thickness: 1.0,
    indent: 0,
    endIndent: 0,
  );

  final BuildContext context;

  @override Color? get color => Theme.of(context).colorScheme.outlineVariant;
}

// END GENERATED TOKEN PROPERTIES - Divider