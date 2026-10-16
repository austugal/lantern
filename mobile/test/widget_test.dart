import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/app.dart';
import 'package:lantern/src/controller.dart';
import 'fakes.dart';

void main() {
  testWidgets('onboarding saves a name without enabling discovery', (
    tester,
  ) async {
    final transport = FakeTransport();
    final c = LanternController(transport, FakeLocation(), FakeProfile(''));
    await c.initialize();
    await tester.pumpWidget(LanternApp(controller: c));
    await tester.enterText(find.byType(TextField), 'Tiago');
    await tester.ensureVisible(find.text('Make yourself at home'));
    await tester.tap(find.text('Make yourself at home'));
    await tester.pumpAndSettle();
    expect(find.text('Turn on Lantern'), findsOneWidget);
    expect(c.name, 'Tiago');
    expect(c.active, isFalse);
    expect(transport.calls.any((v) => v.$1 == 'start'), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('small screen supports discovery and explicit consent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FakeTransport();
    final c = LanternController(transport, FakeLocation(), FakeProfile());
    await c.initialize();
    await tester.pumpWidget(LanternApp(controller: c));
    await tester.tap(find.text('Turn on Lantern'));
    await tester.pumpAndSettle();
    transport.emit('invitation');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Codes match · Accept'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1234'), findsOneWidget);
    await tester.tap(find.text('Codes match · Accept'));
    await tester.pumpAndSettle();
    transport.emit('connected');
    await tester.pumpAndSettle();
    expect(c.connected, isNotNull);
    expect(c.sharing, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
