import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/app.dart';
import 'package:lantern/src/controller.dart';
import 'fakes.dart';

void main() {
  testWidgets('field instruments open without discovery, GPS or sensor start', (
    tester,
  ) async {
    final sensorCalls = <String>[];
    const channel = MethodChannel('org.austugal.lantern/compass');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          sensorCalls.add(call.method);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final transport = FakeTransport();
    final location = FakeLocation();
    final c = LanternController(transport, location, FakeProfile());
    await c.initialize();
    await tester.pumpWidget(LanternApp(controller: c));
    await tester.tap(find.text('Field tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Compass · find north'), 120);
    await tester.tap(find.text('Compass · find north'));
    await tester.pumpAndSettle();
    expect(find.text('Magnetic north'), findsOneWidget);
    expect(sensorCalls, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(sensorCalls, ['stop']);
    await tester.scrollUntilVisible(
      find.text('Calculator & measurements'),
      120,
    );
    await tester.tap(find.text('Calculator & measurements'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Expression'), '7*8');
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();
    expect(find.text('Result: 56'), findsOneWidget);
    expect(transport.calls, isEmpty);
    expect(location.stream.hasListener, isFalse);
    expect(c.navigating, isFalse);
    expect(c.sharing, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await transport.stream.close();
    await location.stream.close();
  });
}
