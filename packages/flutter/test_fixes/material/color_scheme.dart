import 'package:flutter/material.dart';

void main() {
  // Changes made in https://github.com/flutter/flutter/pull/93427
  ColorScheme colorScheme = ColorScheme();
  colorScheme =
      ColorScheme(primaryVariant: Colors.black, secondaryVariant: Colors.white);
  colorScheme = ColorScheme.light(
      primaryVariant: Colors.black, secondaryVariant: Colors.white);
  colorScheme = ColorScheme.dark(
      primaryVariant: Colors.black, secondaryVariant: Colors.white);
  colorScheme = ColorScheme.highContrastLight(
      primaryVariant: Colors.black, secondaryVariant: Colors.white);
  colorScheme = ColorScheme.highContrastDark(
      primaryVariant: Colors.black, secondaryVariant: Colors.white);
  colorScheme = colorScheme.copyWith(
      primaryVariant: Colors.black, secondaryVariant: Colors.white);
  colorScheme.primaryVariant; // Removing field reference not supported.
  colorScheme.secondaryVariant;
}
