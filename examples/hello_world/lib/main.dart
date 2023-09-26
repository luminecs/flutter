import 'package:flutter/widgets.dart';

void main() => runApp(
      const Center(
        child: Text(
          'Hello, world!',
          key: Key('title'),
          textDirection: TextDirection.ltr,
        ),
      ),
    );
