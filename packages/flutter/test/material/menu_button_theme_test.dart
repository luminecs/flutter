import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MenuButtonThemeData lerp special cases', () {
    expect(MenuButtonThemeData.lerp(null, null, 0), null);
    const MenuButtonThemeData data = MenuButtonThemeData();
    expect(identical(MenuButtonThemeData.lerp(data, data, 0.5), data), true);
  });
}