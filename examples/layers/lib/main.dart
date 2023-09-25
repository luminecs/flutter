import 'package:flutter/widgets.dart';

void main() {
  runApp(
    const Center(
      child: Text(
        'Instead run:\nflutter run xxx/yyy.dart',
        textDirection: TextDirection.ltr,
      ),
    ),
  );
}