import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/app.dart';
import 'package:lantern/src/controller.dart';
import 'fakes.dart';

Finder get _notice => find.byKey(const ValueKey('reconnect-notice'));

Finder _noticeAction(String label) =>
    find.descendant(of: _notice, matching: find.text(label));

class _Session {
  final transport = FakeTransport();
  final location = FakeLocation();
  late final controller = LanternController(transport, location, FakeProfile());

  Future<void> mount(WidgetTester tester) async {
    await controller.initialize();
    await controller.start();
    transport.emit('invitation');
    await controller.respond(true);
    transport.emit('connected');
    await tester.pumpWidget(LanternApp(controller: controller));
  }

  Future<void> close(WidgetTester tester) async {
    // LanternApp owns controller disposal; unmount before timer invariants run.
    await tester.pumpWidget(const SizedBox.shrink());
    await transport.stream.close();
    await location.stream.close();
  }

  int calls(String method) =>
      transport.calls.where((call) => call.$1 == method).length;
}

void main() {
  testWidgets('returning to foreground needs a tap and fresh peer consent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final s = _Session();
    await s.mount(tester);
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(_notice, findsOneWidget);
      expect(_noticeAction('Turn on Lantern'), findsOneWidget);
      expect(s.controller.active, isFalse);
      expect(s.controller.connected, isNull);
      expect(s.calls('start'), 1);
      expect(s.calls('accept'), 1);
      expect(s.calls('request'), 0);
      expect(s.location.stream.hasListener, isFalse);
      expect(tester.takeException(), isNull);

      await tester.tap(_noticeAction('Turn on Lantern'));
      await tester.pumpAndSettle();
      expect(_notice, findsNothing);
      expect(s.controller.active, isTrue);
      expect(s.controller.connected, isNull);
      expect(s.calls('start'), 2);
      expect(s.calls('accept'), 1);
      expect(s.calls('request'), 0);

      // A late native connected callback cannot restore the old consent.
      s.transport.emit('connected');
      await tester.pumpAndSettle();
      expect(s.controller.connected, isNull);
      s.transport.emit('invitation', code: '5678');
      await tester.pumpAndSettle();
      expect(s.controller.connected, isNull);
      await tester.scrollUntilVisible(
        find.text('Codes match · Accept'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('5678'), findsOneWidget);
      await tester.tap(find.text('Codes match · Accept'));
      await tester.pumpAndSettle();
      s.transport.emit('connected');
      await tester.pumpAndSettle();
      expect(s.controller.connected?.name, 'Alex');
      expect(s.calls('accept'), 2);
      expect(s.controller.sharing, isFalse);
      expect(s.controller.guardianAccepted, isFalse);
      expect(s.controller.checkInUntil, isNull);
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await s.close(tester);
    }
  });

  testWidgets('peer interruption action only opens nearby discovery controls', (
    tester,
  ) async {
    final s = _Session();
    await s.mount(tester);
    try {
      s.transport.emit('disconnected');
      await tester.pumpAndSettle();
      expect(_noticeAction('Find nearby'), findsOneWidget);
      expect(s.controller.active, isTrue);
      expect(s.controller.connected, isNull);

      await tester.tap(_noticeAction('Find nearby'));
      await tester.pumpAndSettle();
      s.transport.emit('found');
      await tester.pumpAndSettle();
      expect(_notice, findsNothing);
      expect(s.controller.active, isTrue);
      expect(s.controller.connected, isNull);
      expect(s.calls('start'), 1);
      expect(s.calls('accept'), 1);
      expect(s.calls('request'), 0);
      expect(s.controller.sharing, isFalse);
      expect(s.location.stream.hasListener, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      await s.close(tester);
    }
  });

  testWidgets('dismissing a stopped notice never restarts Lantern', (
    tester,
  ) async {
    final s = _Session();
    await s.mount(tester);
    try {
      s.transport.emit('stopped');
      await tester.pumpAndSettle();
      expect(_noticeAction('Turn on Lantern'), findsOneWidget);
      await tester.tap(_noticeAction('Dismiss'));
      await tester.pumpAndSettle();
      expect(_notice, findsNothing);
      expect(s.controller.reconnectReason, isNull);
      expect(s.controller.active, isFalse);
      expect(s.controller.connected, isNull);
      expect(s.calls('start'), 1);
      expect(s.calls('accept'), 1);
      expect(s.calls('request'), 0);
      expect(tester.takeException(), isNull);
    } finally {
      await s.close(tester);
    }
  });

  testWidgets('failed banner restart keeps recovery available until success', (
    tester,
  ) async {
    final s = _Session();
    await s.mount(tester);
    try {
      s.transport.emit('stopped');
      await tester.pumpAndSettle();
      s.transport.failMethod = 'start';
      await tester.tap(_noticeAction('Turn on Lantern'));
      await tester.pumpAndSettle();

      expect(_notice, findsOneWidget);
      expect(_noticeAction('Turn on Lantern'), findsOneWidget);
      expect(find.textContaining('Transport failed'), findsOneWidget);
      expect(s.controller.reconnectReason, ReconnectReason.nativeStopped);
      expect(s.controller.active, isFalse);
      expect(s.controller.connected, isNull);
      expect(s.calls('start'), 2);
      expect(s.calls('accept'), 1);
      expect(s.calls('request'), 0);

      s.transport.failMethod = null;
      await tester.tap(_noticeAction('Turn on Lantern'));
      await tester.pumpAndSettle();
      expect(_notice, findsNothing);
      expect(find.textContaining('Transport failed'), findsNothing);
      expect(s.controller.reconnectReason, isNull);
      expect(s.controller.active, isTrue);
      expect(s.controller.connected, isNull);
      expect(s.calls('start'), 3);
      expect(s.calls('accept'), 1);
      expect(s.calls('request'), 0);
      expect(tester.takeException(), isNull);
    } finally {
      await s.close(tester);
    }
  });
}
