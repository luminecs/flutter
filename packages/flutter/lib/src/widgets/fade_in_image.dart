import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'framework.dart';
import 'image.dart';
import 'implicit_animations.dart';

// Examples can assume:
// late Uint8List bytes;

class FadeInImage extends StatefulWidget {
  const FadeInImage({
    super.key,
    required this.placeholder,
    this.placeholderErrorBuilder,
    required this.image,
    this.imageErrorBuilder,
    this.excludeFromSemantics = false,
    this.imageSemanticLabel,
    this.fadeOutDuration = const Duration(milliseconds: 300),
    this.fadeOutCurve = Curves.easeOut,
    this.fadeInDuration = const Duration(milliseconds: 700),
    this.fadeInCurve = Curves.easeIn,
    this.width,
    this.height,
    this.fit,
    this.placeholderFit,
    this.filterQuality = FilterQuality.low,
    this.placeholderFilterQuality,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
  });

  FadeInImage.memoryNetwork({
    super.key,
    required Uint8List placeholder,
    this.placeholderErrorBuilder,
    required String image,
    this.imageErrorBuilder,
    double placeholderScale = 1.0,
    double imageScale = 1.0,
    this.excludeFromSemantics = false,
    this.imageSemanticLabel,
    this.fadeOutDuration = const Duration(milliseconds: 300),
    this.fadeOutCurve = Curves.easeOut,
    this.fadeInDuration = const Duration(milliseconds: 700),
    this.fadeInCurve = Curves.easeIn,
    this.width,
    this.height,
    this.fit,
    this.placeholderFit,
    this.filterQuality = FilterQuality.low,
    this.placeholderFilterQuality,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    int? placeholderCacheWidth,
    int? placeholderCacheHeight,
    int? imageCacheWidth,
    int? imageCacheHeight,
  })  : placeholder = ResizeImage.resizeIfNeeded(
            placeholderCacheWidth,
            placeholderCacheHeight,
            MemoryImage(placeholder, scale: placeholderScale)),
        image = ResizeImage.resizeIfNeeded(imageCacheWidth, imageCacheHeight,
            NetworkImage(image, scale: imageScale));

  FadeInImage.assetNetwork({
    super.key,
    required String placeholder,
    this.placeholderErrorBuilder,
    required String image,
    this.imageErrorBuilder,
    AssetBundle? bundle,
    double? placeholderScale,
    double imageScale = 1.0,
    this.excludeFromSemantics = false,
    this.imageSemanticLabel,
    this.fadeOutDuration = const Duration(milliseconds: 300),
    this.fadeOutCurve = Curves.easeOut,
    this.fadeInDuration = const Duration(milliseconds: 700),
    this.fadeInCurve = Curves.easeIn,
    this.width,
    this.height,
    this.fit,
    this.placeholderFit,
    this.filterQuality = FilterQuality.low,
    this.placeholderFilterQuality,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    int? placeholderCacheWidth,
    int? placeholderCacheHeight,
    int? imageCacheWidth,
    int? imageCacheHeight,
  })  : placeholder = placeholderScale != null
            ? ResizeImage.resizeIfNeeded(
                placeholderCacheWidth,
                placeholderCacheHeight,
                ExactAssetImage(placeholder,
                    bundle: bundle, scale: placeholderScale))
            : ResizeImage.resizeIfNeeded(
                placeholderCacheWidth,
                placeholderCacheHeight,
                AssetImage(placeholder, bundle: bundle)),
        image = ResizeImage.resizeIfNeeded(imageCacheWidth, imageCacheHeight,
            NetworkImage(image, scale: imageScale));

  final ImageProvider placeholder;

  final ImageErrorWidgetBuilder? placeholderErrorBuilder;

  final ImageProvider image;

  final ImageErrorWidgetBuilder? imageErrorBuilder;

  final Duration fadeOutDuration;

  final Curve fadeOutCurve;

  final Duration fadeInDuration;

  final Curve fadeInCurve;

  final double? width;

  final double? height;

  final BoxFit? fit;

  final BoxFit? placeholderFit;

  final FilterQuality filterQuality;

  final FilterQuality? placeholderFilterQuality;

  final AlignmentGeometry alignment;

  final ImageRepeat repeat;

  final bool matchTextDirection;

  final bool excludeFromSemantics;

  final String? imageSemanticLabel;

  @override
  State<FadeInImage> createState() => _FadeInImageState();
}

class _FadeInImageState extends State<FadeInImage> {
  static const Animation<double> _kOpaqueAnimation =
      AlwaysStoppedAnimation<double>(1.0);
  bool targetLoaded = false;

  // These ProxyAnimations are changed to the fade in animation by
  // [_AnimatedFadeOutFadeInState]. Otherwise these animations are reset to
  // their defaults by [_resetAnimations].
  final ProxyAnimation _imageAnimation = ProxyAnimation(_kOpaqueAnimation);
  final ProxyAnimation _placeholderAnimation =
      ProxyAnimation(_kOpaqueAnimation);

  Image _image({
    required ImageProvider image,
    ImageErrorWidgetBuilder? errorBuilder,
    ImageFrameBuilder? frameBuilder,
    BoxFit? fit,
    required FilterQuality filterQuality,
    required Animation<double> opacity,
  }) {
    return Image(
      image: image,
      errorBuilder: errorBuilder,
      frameBuilder: frameBuilder,
      opacity: opacity,
      width: widget.width,
      height: widget.height,
      fit: fit,
      filterQuality: filterQuality,
      alignment: widget.alignment,
      repeat: widget.repeat,
      matchTextDirection: widget.matchTextDirection,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _image(
      image: widget.image,
      errorBuilder: widget.imageErrorBuilder,
      opacity: _imageAnimation,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      frameBuilder: (BuildContext context, Widget child, int? frame,
          bool wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          targetLoaded = true;
        }
        return _AnimatedFadeOutFadeIn(
          target: child,
          targetProxyAnimation: _imageAnimation,
          placeholder: _image(
            image: widget.placeholder,
            errorBuilder: widget.placeholderErrorBuilder,
            opacity: _placeholderAnimation,
            fit: widget.placeholderFit ?? widget.fit,
            filterQuality:
                widget.placeholderFilterQuality ?? widget.filterQuality,
          ),
          placeholderProxyAnimation: _placeholderAnimation,
          isTargetLoaded: targetLoaded,
          wasSynchronouslyLoaded: wasSynchronouslyLoaded,
          fadeInDuration: widget.fadeInDuration,
          fadeOutDuration: widget.fadeOutDuration,
          fadeInCurve: widget.fadeInCurve,
          fadeOutCurve: widget.fadeOutCurve,
        );
      },
    );

    if (!widget.excludeFromSemantics) {
      result = Semantics(
        container: widget.imageSemanticLabel != null,
        image: true,
        label: widget.imageSemanticLabel ?? '',
        child: result,
      );
    }

    return result;
  }
}

class _AnimatedFadeOutFadeIn extends ImplicitlyAnimatedWidget {
  const _AnimatedFadeOutFadeIn({
    required this.target,
    required this.targetProxyAnimation,
    required this.placeholder,
    required this.placeholderProxyAnimation,
    required this.isTargetLoaded,
    required this.fadeOutDuration,
    required this.fadeOutCurve,
    required this.fadeInDuration,
    required this.fadeInCurve,
    required this.wasSynchronouslyLoaded,
  })  : assert(!wasSynchronouslyLoaded || isTargetLoaded),
        super(duration: fadeInDuration + fadeOutDuration);

  final Widget target;
  final ProxyAnimation targetProxyAnimation;
  final Widget placeholder;
  final ProxyAnimation placeholderProxyAnimation;
  final bool isTargetLoaded;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final Curve fadeInCurve;
  final Curve fadeOutCurve;
  final bool wasSynchronouslyLoaded;

  @override
  _AnimatedFadeOutFadeInState createState() => _AnimatedFadeOutFadeInState();
}

class _AnimatedFadeOutFadeInState
    extends ImplicitlyAnimatedWidgetState<_AnimatedFadeOutFadeIn> {
  Tween<double>? _targetOpacity;
  Tween<double>? _placeholderOpacity;
  Animation<double>? _targetOpacityAnimation;
  Animation<double>? _placeholderOpacityAnimation;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _targetOpacity = visitor(
      _targetOpacity,
      widget.isTargetLoaded ? 1.0 : 0.0,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
    _placeholderOpacity = visitor(
      _placeholderOpacity,
      widget.isTargetLoaded ? 0.0 : 1.0,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  void didUpdateTweens() {
    if (widget.wasSynchronouslyLoaded) {
      // Opacity animations should not be reset if image was synchronously loaded.
      return;
    }

    _placeholderOpacityAnimation =
        animation.drive(TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween:
            _placeholderOpacity!.chain(CurveTween(curve: widget.fadeOutCurve)),
        weight: widget.fadeOutDuration.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(0),
        weight: widget.fadeInDuration.inMilliseconds.toDouble(),
      ),
    ]))
          ..addStatusListener((AnimationStatus status) {
            if (_placeholderOpacityAnimation!.isCompleted) {
              // Need to rebuild to remove placeholder now that it is invisible.
              setState(() {});
            }
          });

    _targetOpacityAnimation =
        animation.drive(TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(0),
        weight: widget.fadeOutDuration.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: _targetOpacity!.chain(CurveTween(curve: widget.fadeInCurve)),
        weight: widget.fadeInDuration.inMilliseconds.toDouble(),
      ),
    ]));

    widget.targetProxyAnimation.parent = _targetOpacityAnimation;
    widget.placeholderProxyAnimation.parent = _placeholderOpacityAnimation;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wasSynchronouslyLoaded ||
        (_placeholderOpacityAnimation?.isCompleted ?? true)) {
      return widget.target;
    }

    return Stack(
      fit: StackFit.passthrough,
      alignment: AlignmentDirectional.center,
      // Text direction is irrelevant here since we're using center alignment,
      // but it allows the Stack to avoid a call to Directionality.of()
      textDirection: TextDirection.ltr,
      children: <Widget>[
        widget.target,
        widget.placeholder,
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Animation<double>>(
        'targetOpacity', _targetOpacityAnimation));
    properties.add(DiagnosticsProperty<Animation<double>>(
        'placeholderOpacity', _placeholderOpacityAnimation));
  }
}
