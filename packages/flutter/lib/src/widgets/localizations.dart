
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'debug.dart';
import 'framework.dart';

// Examples can assume:
// class Intl { Intl._(); static String message(String s, { String? name, String? locale }) => ''; }
// Future<void> initializeMessages(String locale) => Future<void>.value();
// late BuildContext context;
// class Foo { }
// const Widget myWidget = Placeholder();

// Used by loadAll() to record LocalizationsDelegate.load() futures we're
// waiting for.
class _Pending {
  _Pending(this.delegate, this.futureValue);
  final LocalizationsDelegate<dynamic> delegate;
  final Future<dynamic> futureValue;
}

// A utility function used by Localizations to generate one future
// that completes when all of the LocalizationsDelegate.load() futures
// complete. The returned map is indexed by each delegate's type.
//
// The input future values must have distinct types.
//
// The returned Future<Map> will resolve when all of the input map's
// future values have resolved. If all of the input map's values are
// SynchronousFutures then a SynchronousFuture will be returned
// immediately.
//
// This is more complicated than just applying Future.wait to input
// because some of the input.values may be SynchronousFutures. We don't want
// to Future.wait for the synchronous futures.
Future<Map<Type, dynamic>> _loadAll(Locale locale, Iterable<LocalizationsDelegate<dynamic>> allDelegates) {
  final Map<Type, dynamic> output = <Type, dynamic>{};
  List<_Pending>? pendingList;

  // Only load the first delegate for each delegate type that supports
  // locale.languageCode.
  final Set<Type> types = <Type>{};
  final List<LocalizationsDelegate<dynamic>> delegates = <LocalizationsDelegate<dynamic>>[];
  for (final LocalizationsDelegate<dynamic> delegate in allDelegates) {
    if (!types.contains(delegate.type) && delegate.isSupported(locale)) {
      types.add(delegate.type);
      delegates.add(delegate);
    }
  }

  for (final LocalizationsDelegate<dynamic> delegate in delegates) {
    final Future<dynamic> inputValue = delegate.load(locale);
    dynamic completedValue;
    final Future<dynamic> futureValue = inputValue.then<dynamic>((dynamic value) {
      return completedValue = value;
    });
    if (completedValue != null) { // inputValue was a SynchronousFuture
      final Type type = delegate.type;
      assert(!output.containsKey(type));
      output[type] = completedValue;
    } else {
      pendingList ??= <_Pending>[];
      pendingList.add(_Pending(delegate, futureValue));
    }
  }

  // All of the delegate.load() values were synchronous futures, we're done.
  if (pendingList == null) {
    return SynchronousFuture<Map<Type, dynamic>>(output);
  }

  // Some of delegate.load() values were asynchronous futures. Wait for them.
  return Future.wait<dynamic>(pendingList.map<Future<dynamic>>((_Pending p) => p.futureValue))
    .then<Map<Type, dynamic>>((List<dynamic> values) {
      assert(values.length == pendingList!.length);
      for (int i = 0; i < values.length; i += 1) {
        final Type type = pendingList![i].delegate.type;
        assert(!output.containsKey(type));
        output[type] = values[i];
      }
      return output;
    });
}

abstract class LocalizationsDelegate<T> {
  const LocalizationsDelegate();

  bool isSupported(Locale locale);

  Future<T> load(Locale locale);

  bool shouldReload(covariant LocalizationsDelegate<T> old);

  Type get type => T;

  @override
  String toString() => '${objectRuntimeType(this, 'LocalizationsDelegate')}[$type]';
}

abstract class WidgetsLocalizations {
  TextDirection get textDirection;

  String get reorderItemToStart;

  String get reorderItemToEnd;

  String get reorderItemUp;

  String get reorderItemDown;

  String get reorderItemLeft;

  String get reorderItemRight;

  static WidgetsLocalizations of(BuildContext context) {
    assert(debugCheckHasWidgetsLocalizations(context));
    return Localizations.of<WidgetsLocalizations>(context, WidgetsLocalizations)!;
  }
}

class _WidgetsLocalizationsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _WidgetsLocalizationsDelegate();

  // This is convenient simplification. It would be more correct test if the locale's
  // text-direction is LTR.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) => DefaultWidgetsLocalizations.load(locale);

  @override
  bool shouldReload(_WidgetsLocalizationsDelegate old) => false;

  @override
  String toString() => 'DefaultWidgetsLocalizations.delegate(en_US)';
}

class DefaultWidgetsLocalizations implements WidgetsLocalizations {
  const DefaultWidgetsLocalizations();

  @override
  String get reorderItemUp => 'Move up';

  @override
  String get reorderItemDown => 'Move down';

  @override
  String get reorderItemLeft => 'Move left';

  @override
  String get reorderItemRight => 'Move right';

  @override
  String get reorderItemToEnd => 'Move to the end';

  @override
  String get reorderItemToStart => 'Move to the start';

  @override
  TextDirection get textDirection => TextDirection.ltr;

  static Future<WidgetsLocalizations> load(Locale locale) {
    return SynchronousFuture<WidgetsLocalizations>(const DefaultWidgetsLocalizations());
  }

  static const LocalizationsDelegate<WidgetsLocalizations> delegate = _WidgetsLocalizationsDelegate();
}

class _LocalizationsScope extends InheritedWidget {
  const _LocalizationsScope({
    super.key,
    required this.locale,
    required this.localizationsState,
    required this.typeToResources,
    required super.child,
  });

  final Locale locale;
  final _LocalizationsState localizationsState;
  final Map<Type, dynamic> typeToResources;

  @override
  bool updateShouldNotify(_LocalizationsScope old) {
    return typeToResources != old.typeToResources;
  }
}

class Localizations extends StatefulWidget {
  Localizations({
    super.key,
    required this.locale,
    required this.delegates,
    this.child,
  }) : assert(delegates.any((LocalizationsDelegate<dynamic> delegate) => delegate is LocalizationsDelegate<WidgetsLocalizations>));

  factory Localizations.override({
    Key? key,
    required BuildContext context,
    Locale? locale,
    List<LocalizationsDelegate<dynamic>>? delegates,
    Widget? child,
  }) {
    final List<LocalizationsDelegate<dynamic>> mergedDelegates = Localizations._delegatesOf(context);
    if (delegates != null) {
      mergedDelegates.insertAll(0, delegates);
    }
    return Localizations(
      key: key,
      locale: locale ?? Localizations.localeOf(context),
      delegates: mergedDelegates,
      child: child,
    );
  }

  final Locale locale;

  final List<LocalizationsDelegate<dynamic>> delegates;

  final Widget? child;

  static Locale localeOf(BuildContext context) {
    final _LocalizationsScope? scope = context.dependOnInheritedWidgetOfExactType<_LocalizationsScope>();
    assert(() {
      if (scope == null) {
        throw FlutterError(
          'Requested the Locale of a context that does not include a Localizations ancestor.\n'
          'To request the Locale, the context used to retrieve the Localizations widget must '
          'be that of a widget that is a descendant of a Localizations widget.',
        );
      }
      if (scope.localizationsState.locale == null) {
        throw FlutterError(
          'Localizations.localeOf found a Localizations widget that had a unexpected null locale.\n',
        );
      }
      return true;
    }());
    return scope!.localizationsState.locale!;
  }

  static Locale? maybeLocaleOf(BuildContext context) {
    final _LocalizationsScope? scope = context.dependOnInheritedWidgetOfExactType<_LocalizationsScope>();
    return scope?.localizationsState.locale;
  }

  // There doesn't appear to be a need to make this public. See the
  // Localizations.override factory constructor.
  static List<LocalizationsDelegate<dynamic>> _delegatesOf(BuildContext context) {
    final _LocalizationsScope? scope = context.dependOnInheritedWidgetOfExactType<_LocalizationsScope>();
    assert(scope != null, 'a Localizations ancestor was not found');
    return List<LocalizationsDelegate<dynamic>>.of(scope!.localizationsState.widget.delegates);
  }

  static T? of<T>(BuildContext context, Type type) {
    final _LocalizationsScope? scope = context.dependOnInheritedWidgetOfExactType<_LocalizationsScope>();
    return scope?.localizationsState.resourcesFor<T?>(type);
  }

  @override
  State<Localizations> createState() => _LocalizationsState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Locale>('locale', locale));
    properties.add(IterableProperty<LocalizationsDelegate<dynamic>>('delegates', delegates));
  }
}

class _LocalizationsState extends State<Localizations> {
  final GlobalKey _localizedResourcesScopeKey = GlobalKey();
  Map<Type, dynamic> _typeToResources = <Type, dynamic>{};

  Locale? get locale => _locale;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    load(widget.locale);
  }

  bool _anyDelegatesShouldReload(Localizations old) {
    if (widget.delegates.length != old.delegates.length) {
      return true;
    }
    final List<LocalizationsDelegate<dynamic>> delegates = widget.delegates.toList();
    final List<LocalizationsDelegate<dynamic>> oldDelegates = old.delegates.toList();
    for (int i = 0; i < delegates.length; i += 1) {
      final LocalizationsDelegate<dynamic> delegate = delegates[i];
      final LocalizationsDelegate<dynamic> oldDelegate = oldDelegates[i];
      if (delegate.runtimeType != oldDelegate.runtimeType || delegate.shouldReload(oldDelegate)) {
        return true;
      }
    }
    return false;
  }

  @override
  void didUpdateWidget(Localizations old) {
    super.didUpdateWidget(old);
    if (widget.locale != old.locale || (_anyDelegatesShouldReload(old))) {
      load(widget.locale);
    }
  }

  void load(Locale locale) {
    final Iterable<LocalizationsDelegate<dynamic>> delegates = widget.delegates;
    if (delegates.isEmpty) {
      _locale = locale;
      return;
    }

    Map<Type, dynamic>? typeToResources;
    final Future<Map<Type, dynamic>> typeToResourcesFuture = _loadAll(locale, delegates)
      .then<Map<Type, dynamic>>((Map<Type, dynamic> value) {
        return typeToResources = value;
      });

    if (typeToResources != null) {
      // All of the delegates' resources loaded synchronously.
      _typeToResources = typeToResources!;
      _locale = locale;
    } else {
      // - Don't rebuild the dependent widgets until the resources for the new locale
      // have finished loading. Until then the old locale will continue to be used.
      // - If we're running at app startup time then defer reporting the first
      // "useful" frame until after the async load has completed.
      RendererBinding.instance.deferFirstFrame();
      typeToResourcesFuture.then<void>((Map<Type, dynamic> value) {
        if (mounted) {
          setState(() {
            _typeToResources = value;
            _locale = locale;
          });
        }
        RendererBinding.instance.allowFirstFrame();
      });
    }
  }

  T resourcesFor<T>(Type type) {
    final T resources = _typeToResources[type] as T;
    return resources;
  }

  TextDirection get _textDirection {
    final WidgetsLocalizations resources = _typeToResources[WidgetsLocalizations] as WidgetsLocalizations;
    return resources.textDirection;
  }

  @override
  Widget build(BuildContext context) {
    if (_locale == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      textDirection: _textDirection,
      child: _LocalizationsScope(
        key: _localizedResourcesScopeKey,
        locale: _locale!,
        localizationsState: this,
        typeToResources: _typeToResources,
        child: Directionality(
          textDirection: _textDirection,
          child: widget.child!,
        ),
      ),
    );
  }
}