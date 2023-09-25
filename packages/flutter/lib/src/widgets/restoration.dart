// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'framework.dart';

export 'package:flutter/services.dart' show RestorationBucket;

class RestorationScope extends StatefulWidget {
  const RestorationScope({
    super.key,
    required this.restorationId,
    required this.child,
  });

  static RestorationBucket? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UnmanagedRestorationScope>()?.bucket;
  }

  static RestorationBucket of(BuildContext context) {
    final RestorationBucket? bucket = maybeOf(context);
    assert(() {
      if (bucket == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'RestorationScope.of() was called with a context that does not '
            'contain a RestorationScope widget. '
          ),
          ErrorDescription(
            'No RestorationScope widget ancestor could be found starting from '
            'the context that was passed to RestorationScope.of(). This can '
            'happen because you are using a widget that looks for a '
            'RestorationScope ancestor, but no such ancestor exists.\n'
            'The context used was:\n'
            '  $context'
          ),
          ErrorHint(
            'State restoration must be enabled for a RestorationScope to exist. '
            'This can be done by passing a restorationScopeId to MaterialApp, '
            'CupertinoApp, or WidgetsApp at the root of the widget tree or by '
            'wrapping the widget tree in a RootRestorationScope.'
          ),
        ],
        );
      }
      return true;
    }());
    return bucket!;
  }

  final Widget child;

  final String? restorationId;

  @override
  State<RestorationScope> createState() => _RestorationScopeState();
}

class _RestorationScopeState extends State<RestorationScope> with RestorationMixin {
  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    // Nothing to do.
    // The bucket gets injected into the widget tree in the build method.
  }

  @override
  Widget build(BuildContext context) {
    return UnmanagedRestorationScope(
      bucket: bucket, // `bucket` is provided by the RestorationMixin.
      child: widget.child,
    );
  }
}

class UnmanagedRestorationScope extends InheritedWidget {
  const UnmanagedRestorationScope({
    super.key,
    this.bucket,
    required super.child,
  });

  final RestorationBucket? bucket;

  @override
  bool updateShouldNotify(UnmanagedRestorationScope oldWidget) {
    return oldWidget.bucket != bucket;
  }
}

class RootRestorationScope extends StatefulWidget {
  const RootRestorationScope({
    super.key,
    required this.restorationId,
    required this.child,
  });

  final Widget child;

  final String? restorationId;

  @override
  State<RootRestorationScope> createState() => _RootRestorationScopeState();
}

class _RootRestorationScopeState extends State<RootRestorationScope> {
  bool? _okToRenderBlankContainer;
  bool _rootBucketValid = false;
  RestorationBucket? _rootBucket;
  RestorationBucket? _ancestorBucket;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ancestorBucket = RestorationScope.maybeOf(context);
    _loadRootBucketIfNecessary();
    _okToRenderBlankContainer ??= widget.restorationId != null && _needsRootBucketInserted;
  }

  @override
  void didUpdateWidget(RootRestorationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadRootBucketIfNecessary();
  }

  bool get _needsRootBucketInserted => _ancestorBucket == null;

  bool get _isWaitingForRootBucket {
    return widget.restorationId != null && _needsRootBucketInserted && !_rootBucketValid;
  }

  bool _isLoadingRootBucket = false;

  void _loadRootBucketIfNecessary() {
    if (_isWaitingForRootBucket && !_isLoadingRootBucket) {
      _isLoadingRootBucket = true;
      RendererBinding.instance.deferFirstFrame();
      ServicesBinding.instance.restorationManager.rootBucket.then((RestorationBucket? bucket) {
        _isLoadingRootBucket = false;
        if (mounted) {
          ServicesBinding.instance.restorationManager.addListener(_replaceRootBucket);
          setState(() {
            _rootBucket = bucket;
            _rootBucketValid = true;
            _okToRenderBlankContainer = false;
          });
        }
        RendererBinding.instance.allowFirstFrame();
      });
    }
  }

  void _replaceRootBucket() {
    _rootBucketValid = false;
    _rootBucket = null;
    ServicesBinding.instance.restorationManager.removeListener(_replaceRootBucket);
    _loadRootBucketIfNecessary();
    assert(!_isWaitingForRootBucket); // Ensure that load finished synchronously.
  }

  @override
  void dispose() {
    if (_rootBucketValid) {
      ServicesBinding.instance.restorationManager.removeListener(_replaceRootBucket);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_okToRenderBlankContainer! && _isWaitingForRootBucket) {
      return const SizedBox.shrink();
    }

    return UnmanagedRestorationScope(
      bucket: _ancestorBucket ?? _rootBucket,
      child: RestorationScope(
        restorationId: widget.restorationId,
        child: widget.child,
      ),
    );
  }
}

abstract class RestorableProperty<T> extends ChangeNotifier {
  RestorableProperty(){
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  T createDefaultValue();

  T fromPrimitives(Object? data);

  void initWithValue(T value);

  Object? toPrimitives();

  bool get enabled => true;

  bool _disposed = false;

  @override
  void dispose() {
    assert(ChangeNotifier.debugAssertNotDisposed(this)); // FYI, This uses ChangeNotifier's _debugDisposed, not _disposed.
    _owner?._unregister(this);
    super.dispose();
    _disposed = true;
  }

  // ID under which the property has been registered with the RestorationMixin.
  String? _restorationId;
  RestorationMixin? _owner;
  void _register(String restorationId, RestorationMixin owner) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    _restorationId = restorationId;
    _owner = owner;
  }
  void _unregister() {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(_restorationId != null);
    assert(_owner != null);
    _restorationId = null;
    _owner = null;
  }

  @protected
  State get state {
    assert(isRegistered);
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    return _owner!;
  }

  @protected
  bool get isRegistered {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    return _restorationId != null;
  }
}

@optionalTypeArgs
mixin RestorationMixin<S extends StatefulWidget> on State<S> {
  @protected
  String? get restorationId;

  RestorationBucket? get bucket => _bucket;
  RestorationBucket? _bucket;

  @mustCallSuper
  @protected
  void restoreState(RestorationBucket? oldBucket, bool initialRestore);

  @mustCallSuper
  @protected
  void didToggleBucket(RestorationBucket? oldBucket) {
    // When a bucket is replaced, must `restoreState` is called instead.
    assert(_bucket?.isReplacing != true);
  }

  // Maps properties to their listeners.
  final Map<RestorableProperty<Object?>, VoidCallback> _properties = <RestorableProperty<Object?>, VoidCallback>{};

  @protected
  void registerForRestoration(RestorableProperty<Object?> property, String restorationId) {
    assert(property._restorationId == null || (_debugDoingRestore && property._restorationId == restorationId),
           'Property is already registered under ${property._restorationId}.',
    );
    assert(_debugDoingRestore || !_properties.keys.map((RestorableProperty<Object?> r) => r._restorationId).contains(restorationId),
           '"$restorationId" is already registered to another property.',
    );
    final bool hasSerializedValue = bucket?.contains(restorationId) ?? false;
    final Object? initialValue = hasSerializedValue
        ? property.fromPrimitives(bucket!.read<Object>(restorationId))
        : property.createDefaultValue();

    if (!property.isRegistered) {
      property._register(restorationId, this);
      void listener() {
        if (bucket == null) {
          return;
        }
        _updateProperty(property);
      }
      property.addListener(listener);
      _properties[property] = listener;
    }

    assert(
      property._restorationId == restorationId &&
      property._owner == this &&
      _properties.containsKey(property),
    );

    property.initWithValue(initialValue);
    if (!hasSerializedValue && property.enabled && bucket != null) {
      _updateProperty(property);
    }

    assert(() {
      _debugPropertiesWaitingForReregistration?.remove(property);
      return true;
    }());
  }

  @protected
  void unregisterFromRestoration(RestorableProperty<Object?> property) {
    assert(property._owner == this);
    _bucket?.remove<Object?>(property._restorationId!);
    _unregister(property);
  }

  @protected
  void didUpdateRestorationId() {
    // There's nothing to do if:
    //  - We don't have a parent to claim a bucket from.
    //  - Our current bucket already uses the provided restoration ID.
    //  - There's a restore pending, which means that didChangeDependencies
    //    will be called and we handle the rename there.
    if (_currentParent == null || _bucket?.restorationId == restorationId || restorePending) {
      return;
    }

    final RestorationBucket? oldBucket = _bucket;
    assert(!restorePending);
    final bool didReplaceBucket = _updateBucketIfNecessary(parent: _currentParent, restorePending: false);
    if (didReplaceBucket) {
      assert(oldBucket != _bucket);
      assert(_bucket == null || oldBucket == null);
      oldBucket?.dispose();
    }
  }

  @override
  void didUpdateWidget(S oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateRestorationId();
  }

  bool get restorePending {
    if (_firstRestorePending) {
      return true;
    }
    if (restorationId == null) {
      return false;
    }
    final RestorationBucket? potentialNewParent = RestorationScope.maybeOf(context);
    return potentialNewParent != _currentParent && (potentialNewParent?.isReplacing ?? false);
  }

  List<RestorableProperty<Object?>>? _debugPropertiesWaitingForReregistration;
  bool get _debugDoingRestore => _debugPropertiesWaitingForReregistration != null;

  bool _firstRestorePending = true;
  RestorationBucket? _currentParent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final RestorationBucket? oldBucket = _bucket;
    final bool needsRestore = restorePending;
    _currentParent = RestorationScope.maybeOf(context);

    final bool didReplaceBucket = _updateBucketIfNecessary(parent: _currentParent, restorePending: needsRestore);

    if (needsRestore) {
      _doRestore(oldBucket);
    }
    if (didReplaceBucket) {
      assert(oldBucket != _bucket);
      oldBucket?.dispose();
    }
  }

  void _doRestore(RestorationBucket? oldBucket) {
    assert(() {
      _debugPropertiesWaitingForReregistration = _properties.keys.toList();
      return true;
    }());

    restoreState(oldBucket, _firstRestorePending);
    _firstRestorePending = false;

    assert(() {
      if (_debugPropertiesWaitingForReregistration!.isNotEmpty) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'Previously registered RestorableProperties must be re-registered in "restoreState".',
          ),
          ErrorDescription(
            'The RestorableProperties with the following IDs were not re-registered to $this when '
                '"restoreState" was called:',
          ),
          ..._debugPropertiesWaitingForReregistration!.map((RestorableProperty<Object?> property) => ErrorDescription(
            ' * ${property._restorationId}',
          )),
        ]);
      }
      _debugPropertiesWaitingForReregistration = null;
      return true;
    }());
  }

  // Returns true if `bucket` has been replaced with a new bucket. It's the
  // responsibility of the caller to dispose the old bucket when this returns true.
  bool _updateBucketIfNecessary({
    required RestorationBucket? parent,
    required bool restorePending,
  }) {
    if (restorationId == null || parent == null) {
      final bool didReplace = _setNewBucketIfNecessary(newBucket: null, restorePending: restorePending);
      assert(_bucket == null);
      return didReplace;
    }
    assert(restorationId != null);
    if (restorePending || _bucket == null) {
      final RestorationBucket newBucket = parent.claimChild(restorationId!, debugOwner: this);
      final bool didReplace = _setNewBucketIfNecessary(newBucket: newBucket, restorePending: restorePending);
      assert(_bucket == newBucket);
      return didReplace;
    }
    // We have an existing bucket, make sure it has the right parent and id.
    assert(_bucket != null);
    assert(!restorePending);
    _bucket!.rename(restorationId!);
    parent.adoptChild(_bucket!);
    return false;
  }

  // Returns true if `bucket` has been replaced with a new bucket. It's the
  // responsibility of the caller to dispose the old bucket when this returns true.
  bool _setNewBucketIfNecessary({required RestorationBucket? newBucket, required bool restorePending}) {
    if (newBucket == _bucket) {
      return false;
    }
    final RestorationBucket? oldBucket = _bucket;
    _bucket = newBucket;
    if (!restorePending) {
      // Write the current property values into the new bucket to persist them.
      if (_bucket != null) {
        _properties.keys.forEach(_updateProperty);
      }
      didToggleBucket(oldBucket);
    }
    return true;
  }

  void _updateProperty(RestorableProperty<Object?> property) {
    if (property.enabled) {
      _bucket?.write(property._restorationId!, property.toPrimitives());
    } else {
      _bucket?.remove<Object>(property._restorationId!);
    }
  }

  void _unregister(RestorableProperty<Object?> property) {
    final VoidCallback listener = _properties.remove(property)!;
    assert(() {
      _debugPropertiesWaitingForReregistration?.remove(property);
      return true;
    }());
    property.removeListener(listener);
    property._unregister();
  }

  @override
  void dispose() {
    _properties.forEach((RestorableProperty<Object?> property, VoidCallback listener) {
      if (!property._disposed) {
        property.removeListener(listener);
      }
    });
    _bucket?.dispose();
    _bucket = null;
    super.dispose();
  }
}