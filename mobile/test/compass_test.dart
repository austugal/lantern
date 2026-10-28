import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/compass.dart';

class FakeCompass implements CompassSensor {
  final calls = <String>[];
  Map<Object?, Object?>? sample = {
    'heading': 90.0,
    'ageMillis': 0,
    'accuracy': 'high',
  };
  Completer<void>? pendingStart;
  Completer<Map<Object?, Object?>?>? pendingRead;
  bool failStart = false;
  bool failRead = false;
  @override
  Future<void> start() async {
    calls.add('start');
    if (failStart) throw StateError('No sensor');
    if (pendingStart != null) await pendingStart!.future;
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<Map<Object?, Object?>?> read() async {
    calls.add('read');
    if (failRead) throw StateError('Read failed');
    if (pendingRead != null) return pendingRead!.future;
    return sample;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cardinal boundaries wrap at north', () {
    expect(compassCardinal(0), 'N');
    expect(compassCardinal(22.49), 'N');
    expect(compassCardinal(22.5), 'NE');
    expect(compassCardinal(90), 'E');
    expect(compassCardinal(180), 'S');
    expect(compassCardinal(270), 'W');
    expect(compassCardinal(359.99), 'N');
  });

  testWidgets('opening starts no sensor; explicit start polls at four hertz', (
    tester,
  ) async {
    final sensor = FakeCompass();
    final c = CompassController(sensor: sensor);
    expect(sensor.calls, isEmpty);
    await c.start();
    await tester.pump();
    expect(c.heading, 90);
    expect(c.accuracy, 'high');
    expect(sensor.calls, ['start', 'read']);
    await tester.pump(const Duration(milliseconds: 249));
    expect(sensor.calls.where((s) => s == 'read').length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(sensor.calls.where((s) => s == 'read').length, 2);
    await c.stop();
    expect(c.heading, isNull);
    final count = sensor.calls.length;
    await tester.pump(const Duration(seconds: 3));
    expect(sensor.calls.length, count);
    c.dispose();
    await tester.pump();
  });

  testWidgets('stale and malformed samples never display a direction', (
    tester,
  ) async {
    final sensor = FakeCompass();
    final c = CompassController(sensor: sensor);
    await c.start();
    await tester.pump();
    expect(c.heading, 90);
    for (final sample in <Map<Object?, Object?>>[
      {'heading': 90, 'ageMillis': 2000},
      {'heading': 90, 'ageMillis': 0, 'accuracy': 'unreliable'},
      {'heading': 90, 'ageMillis': 0, 'accuracy': 'tilted'},
      {'heading': 90, 'ageMillis': 0, 'accuracy': 'unknown'},
      {'heading': 90, 'ageMillis': -1},
      {'heading': double.nan, 'ageMillis': 0},
      {'heading': 360, 'ageMillis': 0},
      {'heading': -1, 'ageMillis': 0},
      {'heading': 90},
      {'heading': null, 'ageMillis': 0},
    ]) {
      sensor.sample = sample;
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.heading, isNull);
    }
    c.dispose();
    await tester.pump();
  });

  testWidgets('a delayed native reply cannot revive an already stale heading', (
    tester,
  ) async {
    final sensor = FakeCompass()
      ..pendingRead = Completer<Map<Object?, Object?>?>();
    var now = DateTime.utc(2026);
    final c = CompassController(sensor: sensor, now: () => now);
    await c.start();
    await tester.pump();
    now = now.add(const Duration(seconds: 3));
    sensor.pendingRead!.complete({
      'heading': 90.0,
      'ageMillis': 0,
      'accuracy': 'high',
    });
    await tester.pump();
    expect(c.heading, isNull);
    c.dispose();
    await tester.pump();
  });

  testWidgets(
    'hung read expires last heading and cannot overlap across restart',
    (tester) async {
      final sensor = FakeCompass();
      var now = DateTime.utc(2026);
      final c = CompassController(sensor: sensor, now: () => now);
      await c.start();
      await tester.pump();
      expect(c.heading, 90);
      sensor.pendingRead = Completer<Map<Object?, Object?>?>();
      await tester.pump(const Duration(milliseconds: 250));
      final reads = sensor.calls.where((s) => s == 'read').length;
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(c.heading, isNull);
      expect(sensor.calls.where((s) => s == 'read').length, reads);
      await c.stop();
      await c.start();
      await tester.pump(const Duration(seconds: 1));
      expect(sensor.calls.where((s) => s == 'read').length, reads);
      sensor.pendingRead!.complete({'heading': 120, 'ageMillis': 0});
      await tester.pump();
      expect(c.heading, isNull); // Old-session completion is ignored.
      sensor.pendingRead = null;
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.heading, 90);
      c.dispose();
      await tester.pump();
    },
  );

  testWidgets('inactive clears heading and resumed never restarts the sensor', (
    tester,
  ) async {
    final sensor = FakeCompass();
    final c = CompassController(sensor: sensor);
    await c.start();
    await tester.pump();
    c.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    expect(c.active, isFalse);
    expect(c.heading, isNull);
    expect(sensor.calls.last, 'stop');
    await c.start();
    expect(sensor.calls.where((s) => s == 'start').length, 1);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));
    expect(sensor.calls.where((s) => s == 'start').length, 1);
    await c.start();
    await tester.pump();
    expect(c.active, isTrue);
    c.dispose();
    await tester.pump();
  });

  testWidgets(
    'stop follows a delayed start and late completion stays stopped',
    (tester) async {
      final sensor = FakeCompass()..pendingStart = Completer<void>();
      final c = CompassController(sensor: sensor);
      final starting = c.start();
      await tester.pump();
      expect(sensor.calls, ['start']);
      final stopping = c.stop();
      expect(c.heading, isNull);
      sensor.pendingStart!.complete();
      await tester.pump();
      await starting;
      await stopping;
      expect(sensor.calls, ['start', 'stop']);
      expect(c.active, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(sensor.calls, ['start', 'stop']);
      c.dispose();
      await tester.pump();
    },
  );

  testWidgets('dispose follows pending start with final shutdown', (
    tester,
  ) async {
    final sensor = FakeCompass()..pendingStart = Completer<void>();
    final c = CompassController(sensor: sensor);
    final starting = c.start();
    await tester.pump();
    c.dispose();
    sensor.pendingStart!.complete();
    await starting;
    await tester.pump();
    expect(sensor.calls, ['start', 'stop']);
    expect(c.active, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(sensor.calls, ['start', 'stop']);
  });

  testWidgets('unavailable sensor and read errors show retry instructions', (
    tester,
  ) async {
    final sensor = FakeCompass()..failStart = true;
    final c = CompassController(sensor: sensor);
    await c.start();
    await tester.pump();
    expect(c.active, isFalse);
    expect(c.error, contains('unavailable'));
    sensor.failStart = false;
    sensor.failRead = true;
    await c.start();
    await tester.pump();
    expect(c.heading, isNull);
    expect(c.error, contains('try again'));
    sensor.failRead = false;
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.heading, 90);
    expect(c.error, isNull);
    c.dispose();
    await tester.pump();
  });

  testWidgets('screen fits small width at enlarged text and stops on leaving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final sensor = FakeCompass();
    final c = CompassController(sensor: sensor);
    await tester.pumpWidget(MaterialApp(home: CompassScreen(controller: c)));
    expect(sensor.calls, isEmpty);
    expect(find.text('Magnetic north'), findsOneWidget);
    await tester.tap(find.text('Start compass'));
    await tester.pump();
    await tester.pump();
    expect(find.text('90° E'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(sensor.calls.last, 'stop');
    expect(c.active, isFalse);
    c.dispose();
    await tester.pump();
  });

  testWidgets('platform bridge uses only the compass channel', (tester) async {
    const channel = MethodChannel('org.austugal.lantern/compass');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'read'
              ? {'heading': 42.0, 'ageMillis': 100, 'accuracy': 'medium'}
              : null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    const sensor = PlatformCompassSensor();
    await sensor.start();
    expect((await sensor.read())?['heading'], 42.0);
    await sensor.stop();
    expect(calls, ['start', 'read', 'stop']);
  });
}
