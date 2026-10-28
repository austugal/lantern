import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract interface class CompassSensor {
  Future<void> start();
  Future<void> stop();
  Future<Map<Object?, Object?>?> read();
}

class PlatformCompassSensor implements CompassSensor {
  const PlatformCompassSensor();
  static const _channel = MethodChannel('org.austugal.lantern/compass');

  @override
  Future<void> start() => _channel.invokeMethod<void>('start');
  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
  @override
  Future<Map<Object?, Object?>?> read() =>
      _channel.invokeMapMethod<Object?, Object?>('read');
}

/// Foreground-only magnetic heading. Opening this controller starts nothing.
class CompassController extends ChangeNotifier with WidgetsBindingObserver {
  CompassController({CompassSensor? sensor, DateTime Function()? now})
    : sensor = sensor ?? const PlatformCompassSensor(),
      _now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  final CompassSensor sensor;
  final DateTime Function() _now;
  bool active = false;
  bool starting = false;
  double? heading;
  String? accuracy;
  String? error;
  bool _foreground = true;
  bool _disposed = false;
  bool _reading = false;
  int _generation = 0;
  DateTime? _sampleAt;
  Timer? _timer;
  Timer? _expiryTimer;
  Future<void> _writes = Future<void>.value();

  bool _current(int generation) =>
      !_disposed && generation == _generation && _foreground;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _write(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<void> start() async {
    if (_disposed || !_foreground || starting || active) return;
    starting = true;
    error = null;
    heading = null;
    accuracy = null;
    _sampleAt = null;
    final generation = ++_generation;
    _changed();
    try {
      await _write(() async {
        if (_current(generation)) await sensor.start();
      });
      if (!_current(generation)) return;
      active = true;
      _timer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _tick(),
      );
      _tick();
    } catch (_) {
      if (_current(generation)) {
        active = false;
        error =
            'Compass unavailable. Your device may not have a working compass sensor.';
        unawaited(_write(sensor.stop).catchError((Object _) {}));
      }
    } finally {
      starting = false;
      _changed();
    }
  }

  void _tick() {
    if (!active || _disposed) return;
    final sampleAt = _sampleAt;
    if (heading != null &&
        (sampleAt == null ||
            _now().difference(sampleAt).inMilliseconds >= 2000)) {
      heading = null;
      accuracy = null;
      _changed();
    }
    // A stuck native read is never multiplied by timers or a new session.
    if (_reading) return;
    _reading = true;
    final generation = _generation;
    unawaited(_read(generation));
  }

  Future<void> _read(int generation) async {
    final requestedAt = _now();
    try {
      final sample = await sensor.read();
      if (!_current(generation) || !active) return;
      final value = sample?['heading'];
      final age = sample?['ageMillis'];
      final quality = sample?['accuracy'];
      final elapsed = _now().difference(requestedAt).inMilliseconds;
      final totalAge = age is num && age.isFinite ? age + elapsed : null;
      if (const ['high', 'medium', 'low'].contains(quality) &&
          value is num &&
          value.isFinite &&
          value >= 0 &&
          value < 360 &&
          age is num &&
          age.isFinite &&
          age >= 0 &&
          elapsed >= 0 &&
          totalAge != null &&
          totalAge < 2000) {
        heading = value.toDouble();
        _sampleAt = _now().subtract(Duration(milliseconds: totalAge.toInt()));
        accuracy = quality is String && quality.length <= 80 ? quality : null;
        error = null;
        _expiryTimer?.cancel();
        _expiryTimer = Timer(
          Duration(milliseconds: 2000 - totalAge.toInt()),
          () {
            if (_current(generation) && active) {
              heading = null;
              accuracy = null;
              _sampleAt = null;
              _changed();
            }
          },
        );
      } else {
        _expiryTimer?.cancel();
        heading = null;
        accuracy = null;
        _sampleAt = null;
      }
      _changed();
    } catch (_) {
      if (_current(generation) && active) {
        heading = null;
        accuracy = null;
        error = 'Compass reading failed. Stop and try again.';
        _changed();
      }
    } finally {
      _reading = false;
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    final generation = ++_generation;
    active = false;
    heading = null;
    accuracy = null;
    _sampleAt = null;
    _timer?.cancel();
    _timer = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _changed();
    // Serialize after any pending start so a late completion cannot restart it.
    try {
      await _write(sensor.stop);
    } catch (_) {
      if (!_disposed && generation == _generation && !active) {
        error = 'Could not confirm compass shutdown. Close Lantern if needed.';
        _changed();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) unawaited(stop());
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    active = false;
    heading = null;
    _timer?.cancel();
    _timer = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_write(sensor.stop).catchError((Object _) {}));
    super.dispose();
  }
}

String compassCardinal(double heading) => const [
  'N',
  'NE',
  'E',
  'SE',
  'S',
  'SW',
  'W',
  'NW',
][((heading + 22.5) / 45).floor() % 8];

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key, this.controller});
  final CompassController? controller;
  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  late final CompassController c = widget.controller ?? CompassController();

  @override
  void dispose() {
    if (widget.controller == null) {
      c.dispose();
    } else {
      unawaited(c.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Compass')),
    body: AnimatedBuilder(
      animation: c,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Magnetic north',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Hold the phone flat. The top of the screen is your heading. '
            'This is magnetic north, not true north.',
          ),
          const SizedBox(height: 20),
          if (c.heading != null) ...[
            Semantics(
              label:
                  '${c.heading!.round() % 360} degrees ${compassCardinal(c.heading!)} from magnetic north',
              child: ExcludeSemantics(
                child: Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Transform.rotate(
                      angle: -c.heading! * math.pi / 180,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Text('N'),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('E'),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Text('S'),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('W'),
                            ),
                            Icon(Icons.north, size: 90),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${c.heading!.round() % 360}° ${compassCardinal(c.heading!)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (c.accuracy != null) Text('Sensor accuracy: ${c.accuracy}'),
          ] else
            Text(
              c.active
                  ? 'Waiting for a fresh heading. No direction is shown without a valid sensor reading.'
                  : 'Compass is off. Tap Start compass to use this phone’s sensor.',
            ),
          if (c.error != null) ...[
            const SizedBox(height: 12),
            Text(c.error!, semanticsLabel: c.error),
          ],
          const SizedBox(height: 16),
          if (c.active || c.starting)
            OutlinedButton.icon(
              onPressed: c.stop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop compass'),
            )
          else
            FilledButton.icon(
              onPressed: c.starting ? null : c.start,
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Start compass'),
            ),
          const SizedBox(height: 16),
          const Text(
            'Move away from magnets, metal surfaces and electrical equipment. '
            'If the reading is unreliable, follow your phone’s calibration guidance. '
            'GPS waypoint bearings elsewhere in Lantern use true north and may differ. '
            'This is a reference aid, not a precision surveying instrument.',
          ),
          const SizedBox(height: 12),
          const Text(
            'No GPS or location sharing is started by this tool. Sensors stop when '
            'you leave this screen or Lantern becomes inactive. Tap Start again after returning. '
            'Unsupported devices show no heading.',
          ),
        ],
      ),
    ),
  );
}
