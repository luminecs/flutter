import 'dart:async';

import 'package:flutter/material.dart';

class LargeImageChangerPage extends StatefulWidget {
  const LargeImageChangerPage({super.key});

  @override
  State<LargeImageChangerPage> createState() => _LargeImageChangerState();
}

class _LargeImageChangerState extends State<LargeImageChangerPage> {
  Timer? _timer;
  int imageIndex = 0;
  late ImageProvider currentImage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    currentImage = ResizeImage(
      const ExactAssetImage('assets/999x1000.png'),
      width: (MediaQuery.of(context).size.width * 2).toInt() + imageIndex,
      height: (MediaQuery.of(context).size.height * 2).toInt() + imageIndex,
      allowUpscaling: true,
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      currentImage.evict().then((_) {
        setState(() {
          imageIndex = (imageIndex + 1) % 6;
          currentImage = ResizeImage(
            const ExactAssetImage('assets/999x1000.png'),
            width: (MediaQuery.of(context).size.width * 2).toInt() + imageIndex,
            height:
                (MediaQuery.of(context).size.height * 2).toInt() + imageIndex,
            allowUpscaling: true,
          );
        });
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image(image: currentImage);
  }
}
