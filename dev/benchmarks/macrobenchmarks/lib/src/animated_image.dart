import 'package:flutter/material.dart';

class AnimatedImagePage extends StatelessWidget {
  const AnimatedImagePage({super.key, this.onFrame});

  final ValueChanged<int>? onFrame;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animated Image'),
      ),
      body: Image.asset(
        'animated_images/animated_flutter_lgtm.gif',
        package: 'flutter_gallery_assets',
        frameBuilder: (BuildContext context, Widget child, int? frame, bool syncCall) {
          if (onFrame != null && frame != null) {
            onFrame?.call(frame);
          }
          return child;
        },
      ),
    );
  }
}