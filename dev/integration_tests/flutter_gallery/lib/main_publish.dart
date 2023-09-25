
import 'gallery/home.dart';
import 'main.dart' as other_main;

// This main chain-calls main.dart's main. This file is used for publishing
// the gallery and removes the 'PREVIEW' banner.
void main() {
  GalleryHome.showPreviewBanner = false;
  other_main.main();
}