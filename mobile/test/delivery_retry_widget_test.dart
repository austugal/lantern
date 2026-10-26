import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/app.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';

import 'fakes.dart';

void main() {
  testWidgets('uncertain send clears draft and retry requires confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FakeTransport();
    final location = FakeLocation();
    final controller = LanternController(transport, location, FakeProfile());
    await controller.initialize();
    await controller.start();
    transport.emit('invitation');
    await controller.respond(true);
    transport.emit('connected');
    await tester.pumpWidget(LanternApp(controller: controller));
    await tester.tap(find.text('Conversation'));
    await tester.pumpAndSettle();

    final composer = find.byType(TextField);
    transport.failMethod = 'send';
    await tester.enterText(composer, 'Please check the service corridor');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    final note = controller.notes.single;
    expect(note.delivery, Delivery.failed);
    expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
    expect(find.text('Delivery unconfirmed'), findsOneWidget);

    await tester.tap(find.text('Retry message'));
    await tester.pumpAndSettle();
    expect(find.textContaining('may already have arrived'), findsOneWidget);
    expect(note.sendAttempts, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(note.sendAttempts, 1);

    await tester.tap(find.text('Retry message'));
    await tester.pumpAndSettle();
    transport.failMethod = null;
    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();
    expect(controller.notes.single, same(note));
    expect(note.sendAttempts, 2);
    final texts = transport.calls
        .where((call) => call.$1 == 'send')
        .map((call) => Packet.decode(call.$2!['data'] as String))
        .whereType<Packet>()
        .where((packet) => packet.kind == 'text');
    expect(texts.map((packet) => packet.id).toSet(), {note.id});

    transport.emit(
      'data',
      data: Packet('ack', newId(), {'id': note.id}).encode(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Retry message'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await transport.stream.close();
    await location.stream.close();
  });
}
