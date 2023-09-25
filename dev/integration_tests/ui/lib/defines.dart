
import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';

void main() {
  enableFlutterDriverExtension();
  runApp(
    const Center(
      child: Text(
        String.fromEnvironment('test.valueA') + String.fromEnvironment('test.valueB'),
        textDirection: TextDirection.ltr,
      ),
    ),
  );
}