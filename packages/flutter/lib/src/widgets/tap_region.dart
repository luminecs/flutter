import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'editable_text.dart';
import 'framework.dart';

// Enable if you want verbose logging about tap region changes.
const bool _kDebugTapRegion = false;

bool _tapRegionDebug(String message, [Iterable<String>? details]) {
  if (_kDebugTapRegion) {
    debugPrint('TAP REGION: $message');
    if (details != null && details.isNotEmpty) {
      for (final String detail in details) {
        debugPrint('    $detail');
      }
    }
  }
  // Return true so that it can be easily used inside of an assert.
  return true;
}

typedef TapRegionCallback = void Function(PointerDownEvent event);

abstract class TapRegionRegistry {
  void registerTapRegion(RenderTapRegion region);

  void unregisterTapRegion(RenderTapRegion region);

  static TapRegionRegistry of(BuildContext context) {
    final TapRegionRegistry? registry = maybeOf(context);
    assert(() {
      if (registry == null) {
        throw FlutterError(
          'TapRegionRegistry.of() was called with a context that does not contain a TapRegionSurface widget.\n'
          'No TapRegionSurface widget ancestor could be found starting from the context that was passed to '
          'TapRegionRegistry.of().\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return registry!;
  }

  static TapRegionRegistry? maybeOf(BuildContext context) {
    return context.findAncestorRenderObjectOfType<RenderTapRegionSurface>();
  }
}

class TapRegionSurface extends SingleChildRenderObjectWidget {
  const TapRegionSurface({
    super.key,
    required Widget super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderTapRegionSurface();
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderProxyBoxWithHitTestBehavior renderObject,
  ) {}
}

class RenderTapRegionSurface extends RenderProxyBoxWithHitTestBehavior implements TapRegionRegistry {
  final Expando<BoxHitTestResult> _cachedResults = Expando<BoxHitTestResult>();
  final Set<RenderTapRegion> _registeredRegions = <RenderTapRegion>{};
  final Map<Object?, Set<RenderTapRegion>> _groupIdToRegions = <Object?, Set<RenderTapRegion>>{};

  @override
  void registerTapRegion(RenderTapRegion region) {
    assert(_tapRegionDebug('Region $region registered.'));
    assert(!_registeredRegions.contains(region));
    _registeredRegions.add(region);
    if (region.groupId != null) {
      _groupIdToRegions[region.groupId] ??= <RenderTapRegion>{};
      _groupIdToRegions[region.groupId]!.add(region);
    }
  }

  @override
  void unregisterTapRegion(RenderTapRegion region) {
    assert(_tapRegionDebug('Region $region unregistered.'));
    assert(_registeredRegions.contains(region));
    _registeredRegions.remove(region);
    if (region.groupId != null) {
      assert(_groupIdToRegions.containsKey(region.groupId));
      _groupIdToRegions[region.groupId]!.remove(region);
      if (_groupIdToRegions[region.groupId]!.isEmpty) {
        _groupIdToRegions.remove(region.groupId);
      }
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      return false;
    }

    final bool hitTarget = hitTestChildren(result, position: position) || hitTestSelf(position);

    if (hitTarget) {
      final BoxHitTestEntry entry = BoxHitTestEntry(this, position);
      _cachedResults[entry] = result;
      result.add(entry);
    }

    return hitTarget;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    assert(() {
      for (final RenderTapRegion region in _registeredRegions) {
        if (!region.enabled) {
          return false;
        }
      }
      return true;
    }(), 'A RenderTapRegion was registered when it was disabled.');

    if (event is! PointerDownEvent || event.buttons != kPrimaryButton) {
      return;
    }

    if (_registeredRegions.isEmpty) {
      assert(_tapRegionDebug('Ignored tap event because no regions are registered.'));
      return;
    }

    final BoxHitTestResult? result = _cachedResults[entry];

    if (result == null) {
      assert(_tapRegionDebug('Ignored tap event because no surface descendants were hit.'));
      return;
    }

    // A child was hit, so we need to call onTapOutside for those regions or
    // groups of regions that were not hit.
    final Set<RenderTapRegion> hitRegions =
        _getRegionsHit(_registeredRegions, result.path).cast<RenderTapRegion>().toSet();
    final Set<RenderTapRegion> insideRegions = <RenderTapRegion>{};
    assert(_tapRegionDebug('Tap event hit ${hitRegions.length} descendants.'));

    for (final RenderTapRegion region in hitRegions) {
      if (region.groupId == null) {
        insideRegions.add(region);
        continue;
      }
      // Add all grouped regions to the insideRegions so that groups act as a
      // single region.
      insideRegions.addAll(_groupIdToRegions[region.groupId]!);
    }
    // If they're not inside, then they're outside.
    final Set<RenderTapRegion> outsideRegions = _registeredRegions.difference(insideRegions);

    for (final RenderTapRegion region in outsideRegions) {
      assert(_tapRegionDebug('Calling onTapOutside for $region'));
      region.onTapOutside?.call(event);
    }
    for (final RenderTapRegion region in insideRegions) {
      assert(_tapRegionDebug('Calling onTapInside for $region'));
      region.onTapInside?.call(event);
    }
  }

  // Returns the registered regions that are in the hit path.
  Iterable<HitTestTarget> _getRegionsHit(Set<RenderTapRegion> detectors, Iterable<HitTestEntry> hitTestPath) {
    final Set<HitTestTarget> hitRegions = <HitTestTarget>{};
    for (final HitTestEntry<HitTestTarget> entry in hitTestPath) {
      final HitTestTarget target = entry.target;
      if (_registeredRegions.contains(target)) {
        hitRegions.add(target);
      }
    }
    return hitRegions;
  }
}

class TapRegion extends SingleChildRenderObjectWidget {
  const TapRegion({
    super.key,
    required super.child,
    this.enabled = true,
    this.behavior = HitTestBehavior.deferToChild,
    this.onTapOutside,
    this.onTapInside,
    this.groupId,
    String? debugLabel,
  }) : debugLabel = kReleaseMode ? null : debugLabel;

  final bool enabled;

  final HitTestBehavior behavior;

  final TapRegionCallback? onTapOutside;

  final TapRegionCallback? onTapInside;

  final Object? groupId;

  final String? debugLabel;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderTapRegion(
      registry: TapRegionRegistry.maybeOf(context),
      enabled: enabled,
      behavior: behavior,
      onTapOutside: onTapOutside,
      onTapInside: onTapInside,
      groupId: groupId,
      debugLabel: debugLabel,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderTapRegion renderObject) {
    renderObject
      ..registry = TapRegionRegistry.maybeOf(context)
      ..enabled = enabled
      ..behavior = behavior
      ..groupId = groupId
      ..onTapOutside = onTapOutside
      ..onTapInside = onTapInside;
    if (!kReleaseMode) {
      renderObject.debugLabel = debugLabel;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'DISABLED', defaultValue: true));
    properties.add(DiagnosticsProperty<HitTestBehavior>('behavior', behavior, defaultValue: HitTestBehavior.deferToChild));
    properties.add(DiagnosticsProperty<Object?>('debugLabel', debugLabel, defaultValue: null));
    properties.add(DiagnosticsProperty<Object?>('groupId', groupId, defaultValue: null));
  }
}

class RenderTapRegion extends RenderProxyBoxWithHitTestBehavior {
  RenderTapRegion({
    TapRegionRegistry? registry,
    bool enabled = true,
    this.onTapOutside,
    this.onTapInside,
    super.behavior = HitTestBehavior.deferToChild,
    Object? groupId,
    String? debugLabel,
  })  : _registry = registry,
        _enabled = enabled,
        _groupId = groupId,
        debugLabel = kReleaseMode ? null : debugLabel;

  bool _isRegistered = false;

  TapRegionCallback? onTapOutside;

  TapRegionCallback? onTapInside;

  String? debugLabel;

  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (_enabled != value) {
      _enabled = value;
      markNeedsLayout();
    }
  }

  Object? get groupId => _groupId;
  Object? _groupId;
  set groupId(Object? value) {
    if (_groupId != value) {
      // If the group changes, we need to unregister and re-register under the
      // new group. The re-registration happens automatically in layout().
      if (_isRegistered) {
        _registry!.unregisterTapRegion(this);
        _isRegistered = false;
      }
      _groupId = value;
      markNeedsLayout();
    }
  }

  TapRegionRegistry? get registry => _registry;
  TapRegionRegistry? _registry;
  set registry(TapRegionRegistry? value) {
    if (_registry != value) {
      if (_isRegistered) {
        _registry!.unregisterTapRegion(this);
        _isRegistered = false;
      }
      _registry = value;
      markNeedsLayout();
    }
  }

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    super.layout(constraints, parentUsesSize: parentUsesSize);
    if (_registry == null) {
      return;
    }
    if (_isRegistered) {
      _registry!.unregisterTapRegion(this);
    }
    final bool shouldBeRegistered = _enabled && _registry != null;
    if (shouldBeRegistered) {
      _registry!.registerTapRegion(this);
    }
    _isRegistered = shouldBeRegistered;
  }

  @override
  void dispose() {
    if (_isRegistered) {
      _registry!.unregisterTapRegion(this);
    }
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<String?>('debugLabel', debugLabel, defaultValue: null));
    properties.add(DiagnosticsProperty<Object?>('groupId', groupId, defaultValue: null));
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'DISABLED', defaultValue: true));
  }
}

class TextFieldTapRegion extends TapRegion {
  const TextFieldTapRegion({
    super.key,
    required super.child,
    super.enabled,
    super.onTapOutside,
    super.onTapInside,
    super.debugLabel,
  }) : super(groupId: EditableText);
}