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
    await tester.ensureVisible(find.text('Turn on Lantern'));
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
  testWidgets('help explains controls without starting discovery or GPS', (
    tester,
  ) async {
    final transport = FakeTransport();
    final location = _CountingLocation();
    final c = LanternController(transport, location, FakeProfile());
    await c.initialize();
    await tester.pumpWidget(LanternApp(controller: c));

    await tester.tap(find.byTooltip('Explain Quick start'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Quick start'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Field tools'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Explain Offline navigation'));
    await tester.tap(find.byTooltip('Explain Offline navigation'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining('This does not share your position.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(transport.calls, isEmpty);
    expect(location.authorizationRequests, 0);
    expect(c.active, isFalse);
    expect(c.navigating, isFalse);
    expect(c.sharing, isFalse);
    expect(c.checkInUntil, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('field tools and help fit a small phone without a connection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FakeTransport();
    final location = _CountingLocation();
    final c = LanternController(transport, location, FakeProfile());
    await c.initialize();
    await tester.pumpWidget(LanternApp(controller: c));
    await tester.tap(find.text('Field tools'));
    await tester.pumpAndSettle();

    for (final title in [
      'Disappearing messages',
      'Location sharing',
      'Offline navigation',
      'Buddy check-in',
    ]) {
      final help = find.byTooltip('Explain $title');
      await tester.ensureVisible(help);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$title panel should fit');
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '$title help should scroll',
      );
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
    }

    final askGuardian = tester.widget<OutlinedButton>(
      find.widgetWithText(
        OutlinedButton,
        'Ask connected person to be guardian',
      ),
    );
    expect(askGuardian.onPressed, isNull);
    expect(find.text('Send buddy SOS'), findsNothing);
    expect(transport.calls, isEmpty);
    expect(location.authorizationRequests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _CountingLocation extends FakeLocation {
  int authorizationRequests = 0;

  @override
  Future<void> authorize() async {
    authorizationRequests++;
    await super.authorize();
  }
}
