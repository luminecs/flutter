
import 'package:flutter/material.dart';

void main() {
  // Changes made in https://github.com/flutter/flutter/pull/86198
  AppBar appBar = AppBar();
  appBar = AppBar(brightness: Brightness.light);
  appBar = AppBar(brightness: Brightness.dark);
  appBar = AppBar(error: '');
  appBar.brightness;

  TextTheme myTextTheme = TextTheme();
  AppBar appBar = AppBar();
  appBar = AppBar(textTheme: myTextTheme);
  appBar = AppBar(textTheme: myTextTheme);

  AppBar appBar = AppBar();
  appBar = AppBar(backwardsCompatibility: true);
  appBar = AppBar(backwardsCompatibility: false));
  appBar.backwardsCompatibility; // Removing field reference not supported.
}