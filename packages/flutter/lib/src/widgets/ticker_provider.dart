import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'framework.dart';

export 'package:flutter/scheduler.dart' show TickerProvider;

// Examples can assume:
// late BuildContext context;

class TickerMode extends StatefulWidget {
  const TickerMode({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;

  final Widget child;

  static bool of(BuildContext context) {
    final _EffectiveTickerMode? widget = context.dependOnInheritedWidgetOfExactType<_EffectiveTickerMode>();
    return widget?.enabled ?? true;
  }

  static ValueListenable<bool> getNotifier(BuildContext context) {
    final _EffectiveTickerMode? widget = context.getInheritedWidgetOfExactType<_EffectiveTickerMode>();
    return widget?.notifier ?? const _ConstantValueListenable<bool>(true);
  }

  @override
  State<TickerMode> createState() => _TickerModeState();
}

class _TickerModeState extends State<TickerMode> {
  bool _ancestorTicketMode = true;
  final ValueNotifier<bool> _effectiveMode = ValueNotifier<bool>(true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ancestorTicketMode = TickerMode.of(context);
    _updateEffectiveMode();
  }

  @override
  void didUpdateWidget(TickerMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateEffectiveMode();
  }

  @override
  void dispose() {
    _effectiveMode.dispose();
    super.dispose();
  }

  void _updateEffectiveMode() {
    _effectiveMode.value = _ancestorTicketMode && widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return _EffectiveTickerMode(
      enabled: _effectiveMode.value,
      notifier: _effectiveMode,
      child: widget.child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('requested mode', value: widget.enabled, ifTrue: 'enabled', ifFalse: 'disabled', showName: true));
  }
}

class _EffectiveTickerMode extends InheritedWidget {
  const _EffectiveTickerMode({
    required this.enabled,
    required this.notifier,
    required super.child,
  });

  final bool enabled;
  final ValueNotifier<bool> notifier;

  @override
  bool updateShouldNotify(_EffectiveTickerMode oldWidget) => enabled != oldWidget.enabled;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('effective mode', value: enabled, ifTrue: 'enabled', ifFalse: 'disabled', showName: true));
  }
}

@optionalTypeArgs
mixin SingleTickerProviderStateMixin<T extends StatefulWidget> on State<T> implements TickerProvider {
  Ticker? _ticker;

  @override
  Ticker createTicker(TickerCallback onTick) {
    assert(() {
      if (_ticker == null) {
        return true;
      }
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('$runtimeType is a SingleTickerProviderStateMixin but multiple tickers were created.'),
        ErrorDescription('A SingleTickerProviderStateMixin can only be used as a TickerProvider once.'),
        ErrorHint(
          'If a State is used for multiple AnimationController objects, or if it is passed to other '
          'objects and those objects might use it more than one time in total, then instead of '
          'mixing in a SingleTickerProviderStateMixin, use a regular TickerProviderStateMixin.',
        ),
      ]);
    }());
    _ticker = Ticker(onTick, debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null);
    _updateTickerModeNotifier();
    _updateTicker(); // Sets _ticker.mute correctly.
    return _ticker!;
  }

  @override
  void dispose() {
    assert(() {
      if (_ticker == null || !_ticker!.isActive) {
        return true;
      }
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('$this was disposed with an active Ticker.'),
        ErrorDescription(
          '$runtimeType created a Ticker via its SingleTickerProviderStateMixin, but at the time '
          'dispose() was called on the mixin, that Ticker was still active. The Ticker must '
          'be disposed before calling super.dispose().',
        ),
        ErrorHint(
          'Tickers used by AnimationControllers '
          'should be disposed by calling dispose() on the AnimationController itself. '
          'Otherwise, the ticker will leak.',
        ),
        _ticker!.describeForError('The offending ticker was'),
      ]);
    }());
    _tickerModeNotifier?.removeListener(_updateTicker);
    _tickerModeNotifier = null;
    super.dispose();
  }

  ValueListenable<bool>? _tickerModeNotifier;

  @override
  void activate() {
    super.activate();
    // We may have a new TickerMode ancestor.
    _updateTickerModeNotifier();
    _updateTicker();
  }

  void _updateTicker() {
    if (_ticker != null) {
      _ticker!.muted = !_tickerModeNotifier!.value;
    }
  }

  void _updateTickerModeNotifier() {
    final ValueListenable<bool> newNotifier = TickerMode.getNotifier(context);
    if (newNotifier == _tickerModeNotifier) {
      return;
    }
    _tickerModeNotifier?.removeListener(_updateTicker);
    newNotifier.addListener(_updateTicker);
    _tickerModeNotifier = newNotifier;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    String? tickerDescription;
    if (_ticker != null) {
      if (_ticker!.isActive && _ticker!.muted) {
        tickerDescription = 'active but muted';
      } else if (_ticker!.isActive) {
        tickerDescription = 'active';
      } else if (_ticker!.muted) {
        tickerDescription = 'inactive and muted';
      } else {
        tickerDescription = 'inactive';
      }
    }
    properties.add(DiagnosticsProperty<Ticker>('ticker', _ticker, description: tickerDescription, showSeparator: false, defaultValue: null));
  }
}

@optionalTypeArgs
mixin TickerProviderStateMixin<T extends StatefulWidget> on State<T> implements TickerProvider {
  Set<Ticker>? _tickers;

  @override
  Ticker createTicker(TickerCallback onTick) {
    if (_tickerModeNotifier == null) {
      // Setup TickerMode notifier before we vend the first ticker.
      _updateTickerModeNotifier();
    }
    assert(_tickerModeNotifier != null);
    _tickers ??= <_WidgetTicker>{};
    final _WidgetTicker result = _WidgetTicker(onTick, this, debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null)
      ..muted = !_tickerModeNotifier!.value;
    _tickers!.add(result);
    return result;
  }

  void _removeTicker(_WidgetTicker ticker) {
    assert(_tickers != null);
    assert(_tickers!.contains(ticker));
    _tickers!.remove(ticker);
  }

  ValueListenable<bool>? _tickerModeNotifier;

  @override
  void activate() {
    super.activate();
    // We may have a new TickerMode ancestor, get its Notifier.
    _updateTickerModeNotifier();
    _updateTickers();
  }

  void _updateTickers() {
    if (_tickers != null) {
      final bool muted = !_tickerModeNotifier!.value;
      for (final Ticker ticker in _tickers!) {
        ticker.muted = muted;
      }
    }
  }

  void _updateTickerModeNotifier() {
    final ValueListenable<bool> newNotifier = TickerMode.getNotifier(context);
    if (newNotifier == _tickerModeNotifier) {
      return;
    }
    _tickerModeNotifier?.removeListener(_updateTickers);
    newNotifier.addListener(_updateTickers);
    _tickerModeNotifier = newNotifier;
  }

  @override
  void dispose() {
    assert(() {
      if (_tickers != null) {
        for (final Ticker ticker in _tickers!) {
          if (ticker.isActive) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('$this was disposed with an active Ticker.'),
              ErrorDescription(
                '$runtimeType created a Ticker via its TickerProviderStateMixin, but at the time '
                'dispose() was called on the mixin, that Ticker was still active. All Tickers must '
                'be disposed before calling super.dispose().',
              ),
              ErrorHint(
                'Tickers used by AnimationControllers '
                'should be disposed by calling dispose() on the AnimationController itself. '
                'Otherwise, the ticker will leak.',
              ),
              ticker.describeForError('The offending ticker was'),
            ]);
          }
        }
      }
      return true;
    }());
    _tickerModeNotifier?.removeListener(_updateTickers);
    _tickerModeNotifier = null;
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Set<Ticker>>(
      'tickers',
      _tickers,
      description: _tickers != null ?
        'tracking ${_tickers!.length} ticker${_tickers!.length == 1 ? "" : "s"}' :
        null,
      defaultValue: null,
    ));
  }
}

// This class should really be called _DisposingTicker or some such, but this
// class name leaks into stack traces and error messages and that name would be
// confusing. Instead we use the less precise but more anodyne "_WidgetTicker",
// which attracts less attention.
class _WidgetTicker extends Ticker {
  _WidgetTicker(super.onTick, this._creator, { super.debugLabel });

  final TickerProviderStateMixin _creator;

  @override
  void dispose() {
    _creator._removeTicker(this);
    super.dispose();
  }
}

class _ConstantValueListenable<T> implements ValueListenable<T> {
  const _ConstantValueListenable(this.value);

  @override
  void addListener(VoidCallback listener) {
    // Intentionally left empty: Value cannot change, so we never have to
    // notify registered listeners.
  }

  @override
  void removeListener(VoidCallback listener) {
    // Intentionally left empty: Value cannot change, so we never have to
    // notify registered listeners.
  }

  @override
  final T value;
}