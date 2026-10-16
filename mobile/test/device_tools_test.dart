import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/device_tools.dart';

class FakeTools implements DeviceTools {
  final calls = <bool>[];
  bool failOn = false;
  bool failOff = false;
  Completer<void>? pendingOn;
  @override
  Future<void> setTorch(bool enabled) async {
    calls.add(enabled);
    if ((enabled && failOn) || (!enabled && failOff)) {
      throw StateError('hardware unavailable');
    }
    if (enabled && pendingOn != null) await pendingOn!.future;
  }

  @override
  Future<bool> requestNotifications() async => true;
  @override
  Future<bool> notifyMessage() async => true;
  @override
  Future<void> clearNotifications() async {}
  @override
  Future<void> openAppSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('SOS follows short and long timing; Stop cancels future marks', (
    tester,
  ) async {
    final tools = FakeTools();
    final controller = TorchController(tools);
    await controller.startSos();
    await tester.pump();
    expect(tools.calls, [true]);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(tools.calls, [true, false, true, false, true, false]);
    await tester.pump(const Duration(milliseconds: 749));
    expect(tools.calls.length, 6);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tools.calls.last, true); // O starts after the three-unit letter gap.
    await tester.pump(const Duration(milliseconds: 749));
    expect(tools.calls.length, 7);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tools.calls.last, false);
    await controller.stop();
    final count = tools.calls.length;
    await tester.pump(const Duration(seconds: 20));
    expect(tools.calls.length, count);
    expect(controller.sosActive, false);
    expect(controller.torchOn, false);
    controller.dispose();
    await tester.pump();
  });

  testWidgets('inactive permission dialog does not cancel torch request', (
    tester,
  ) async {
    final tools = FakeTools();
    final controller = TorchController(tools);
    await controller.startSos();
    await tester.pump();
    controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    expect(controller.sosActive, true);
    expect(tools.calls, [true]);
    await controller.stop();
    controller.dispose();
    await tester.pump();
  });

  testWidgets('background cancels signal and turns torch off', (tester) async {
    final tools = FakeTools();
    final controller = TorchController(tools);
    await controller.startSos();
    await tester.pump();
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(tools.calls.last, false);
    expect(controller.sosActive, false);
    final count = tools.calls.length;
    await tester.pump(const Duration(seconds: 20));
    expect(tools.calls.length, count);
    controller.dispose();
    await tester.pump();
  });

  testWidgets('Stop queues OFF after an outstanding hardware ON', (
    tester,
  ) async {
    final tools = FakeTools()..pendingOn = Completer<void>();
    final controller = TorchController(tools);
    await controller.startSos();
    await tester.pump();
    final stopped = controller.stop();
    expect(controller.sosActive, false);
    expect(tools.calls, [true, false]); // OFF does not wait for permission.
    tools.pendingOn!.complete();
    await tester.pump();
    await stopped;
    expect(tools.calls, [true, false, false]);
    expect(controller.torchOn, false);
    controller.dispose();
    await tester.pump();
  });

  testWidgets('hardware errors stop pattern and surface instructions', (
    tester,
  ) async {
    final tools = FakeTools()..failOn = true;
    final controller = TorchController(tools);
    await controller.startSos();
    await tester.pump();
    expect(controller.sosActive, false);
    expect(controller.error, contains('Torch unavailable'));
    expect(tools.calls.last, false);
    tools.failOff = true;
    await controller.stop();
    expect(controller.error, contains('flashlight control'));
    controller.dispose();
    await tester.pump();
  });

  testWidgets('dispose cancels timing and requests OFF without notifications', (
    tester,
  ) async {
    final tools = FakeTools();
    final controller = TorchController(tools);
    await controller.startSos();
    await tester.pump();
    controller.dispose();
    await tester.pump();
    expect(tools.calls.last, false);
    final count = tools.calls.length;
    await tester.pump(const Duration(seconds: 20));
    expect(tools.calls.length, count);
  });

  test(
    'platform adapter uses native method names without private content',
    () async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('org.austugal.lantern/device');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'requestNotifications' ||
                call.method == 'notifyMessage'
            ? true
            : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const tools = PlatformDeviceTools();
      await tools.setTorch(true);
      expect(await tools.requestNotifications(), true);
      expect(await tools.notifyMessage(), true);
      await tools.clearNotifications();
      await tools.openAppSettings();
      expect(calls.map((c) => c.method), [
        'setTorch',
        'requestNotifications',
        'notifyMessage',
        'clearNotifications',
        'openAppSettings',
      ]);
      expect(calls.first.arguments, {'enabled': true});
      expect(calls[2].arguments, null);
    },
  );
}
