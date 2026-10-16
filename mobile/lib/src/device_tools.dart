import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Device-only utilities. Notifications intentionally contain no message text.
abstract interface class DeviceTools {
  Future<void> setTorch(bool enabled);
  Future<bool> requestNotifications();
  Future<bool> notifyMessage();
  Future<void> clearNotifications();
  Future<void> openAppSettings();
}

class PlatformDeviceTools implements DeviceTools {
  const PlatformDeviceTools();
  static const _channel = MethodChannel('org.austugal.lantern/device');

  @override
  Future<void> setTorch(bool enabled) =>
      _channel.invokeMethod<void>('setTorch', {'enabled': enabled});
  @override
  Future<bool> requestNotifications() async =>
      await _channel.invokeMethod<bool>('requestNotifications') ?? false;
  @override
  Future<bool> notifyMessage() async =>
      await _channel.invokeMethod<bool>('notifyMessage') ?? false;
  @override
  Future<void> clearNotifications() =>
      _channel.invokeMethod<void>('clearNotifications');
  @override
  Future<void> openAppSettings() =>
      _channel.invokeMethod<void>('openAppSettings');
}

/// Foreground visual signal only; it does not contact emergency services.
class TorchController extends ChangeNotifier with WidgetsBindingObserver {
  TorchController(this.tools, {this.unit = const Duration(milliseconds: 250)}) {
    WidgetsBinding.instance.addObserver(this);
  }

  final DeviceTools tools;
  final Duration unit;
  bool torchOn = false;
  bool sosActive = false;
  bool busy = false;
  String? error;
  bool _disposed = false;
  bool _onInFlight = false;
  int _generation = 0;
  Timer? _timer;
  Completer<void>? _delay;
  Future<void> _writes = Future<void>.value();

  // Alternate ON/OFF lengths: S (1,1,1), O (3,3,3), S (1,1,1).
  // One unit between marks, three between letters, seven before repeating.
  static const _pattern = <int>[
    1,
    1,
    1,
    1,
    1,
    3,
    3,
    1,
    3,
    1,
    3,
    3,
    1,
    1,
    1,
    1,
    1,
    7,
  ];

  bool _current(int generation) => !_disposed && generation == _generation;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (_delay != null && !_delay!.isCompleted) _delay!.complete();
    _delay = null;
  }

  // Serialize hardware calls so a late ON completion cannot follow Stop's OFF.
  Future<void> _write(bool enabled, int generation) {
    // OFF bypasses a pending ON permission request so native code can cancel it.
    // A second queued OFF still guarantees the final hardware state if ON completes late.
    final immediateOff = !enabled && _onInFlight
        ? tools.setTorch(false).catchError((Object _) {})
        : Future<void>.value();
    final result = _writes.then((_) async {
      if (enabled && !_current(generation)) return;
      await immediateOff;
      _onInFlight = enabled;
      try {
        await tools.setTorch(enabled);
      } finally {
        _onInFlight = false;
      }
      if (_current(generation)) {
        torchOn = enabled;
        _changed();
      }
    });
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<void> _pause(int units) {
    final completion = Completer<void>();
    _delay = completion;
    _timer = Timer(unit * units, () {
      if (!completion.isCompleted) completion.complete();
      if (identical(_delay, completion)) _delay = null;
    });
    return completion.future;
  }

  Future<void> toggle() async {
    if (_disposed) return;
    final enabled = !torchOn && !sosActive;
    _cancel();
    final generation = _generation;
    sosActive = false;
    busy = true;
    error = null;
    _changed();
    try {
      await _write(enabled, generation);
    } catch (_) {
      await _failed(generation);
    } finally {
      if (_current(generation)) {
        busy = false;
        _changed();
      }
    }
  }

  /// Returns after starting; Stop remains available while the pattern runs.
  Future<void> startSos() async {
    if (_disposed) return;
    _cancel();
    final generation = _generation;
    sosActive = true;
    busy = false;
    error = null;
    _changed();
    unawaited(_signal(generation));
  }

  Future<void> _signal(int generation) async {
    try {
      while (_current(generation) && sosActive) {
        for (var index = 0; index < _pattern.length; index++) {
          if (!_current(generation)) return;
          await _write(index.isEven, generation);
          if (!_current(generation)) return;
          await _pause(_pattern[index]);
        }
      }
    } catch (_) {
      await _failed(generation);
    }
  }

  Future<void> _failed(int generation) async {
    if (!_current(generation)) return;
    _cancel();
    sosActive = false;
    busy = false;
    error =
        'Torch unavailable. Check camera permission and close other camera apps.';
    try {
      await _write(false, _generation);
      torchOn = false;
    } catch (_) {
      error =
          'Could not turn the torch off. Use your phone’s flashlight control.';
    }
    _changed();
  }

  Future<void> stop() async {
    if (_disposed) return;
    _cancel();
    final generation = _generation;
    sosActive = false;
    busy = false;
    error = null;
    _changed();
    try {
      await _write(false, generation);
    } catch (_) {
      if (_current(generation)) {
        error =
            'Could not turn the torch off. Use your phone’s flashlight control.';
        _changed();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(stop());
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _cancel();
    _disposed = true;
    sosActive = false;
    WidgetsBinding.instance.removeObserver(this);
    // Best effort; native code also turns the torch off on background/teardown.
    unawaited(_write(false, _generation).catchError((Object _) {}));
    super.dispose();
  }
}
