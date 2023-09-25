
import 'package:flutter/widgets.dart';

void main() {
  runApp(const Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: Text('flutter run -t xxx.dart'),
    ),
  ));
}