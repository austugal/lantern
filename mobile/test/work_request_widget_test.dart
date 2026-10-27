import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/app.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';

import 'fakes.dart';

Future<void> _connect(
  LanternController controller,
  FakeTransport transport,
) async {
  await controller.initialize();
  await controller.start();
  transport.emit('invitation');
  await controller.respond(true);
  transport.emit('connected');
}

void main() {
  testWidgets('sender explicitly requests and sees a human acknowledgement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FakeTransport();
    final location = FakeLocation();
    final controller = LanternController(transport, location, FakeProfile());
    await _connect(controller, transport);
    await tester.pumpWidget(LanternApp(controller: controller));
    await tester.tap(find.text('Conversation'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Request acknowledgement'));
    await tester.tap(find.text('Request acknowledgement'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Please inspect the service corridor',
    );
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    final request = controller.notes.single;
    expect(request.responseRequested, isTrue);
    expect(find.text('Response requested · waiting'), findsOneWidget);

    transport.emit(
      'data',
      data: Packet('ack', newId(), {'id': request.id}).encode(),
    );
    transport.emit(
      'data',
      data: Packet('text', newId(), {
        'text': 'Accepted',
        'replyTo': request.id,
        'decision': 'accepted',
      }).encode(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accepted by colleague'), findsOneWidget);
    expect(request.workDecision, WorkDecision.accepted);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await transport.stream.close();
    await location.stream.close();
  });

  testWidgets('recipient gets both choices and records one final response', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FakeTransport();
    final location = FakeLocation();
    final controller = LanternController(transport, location, FakeProfile());
    await _connect(controller, transport);
    await tester.pumpWidget(LanternApp(controller: controller));
    await tester.tap(find.text('Conversation'));
    await tester.pumpAndSettle();

    transport.emit(
      'data',
      data: Packet('text', newId(), {
        'text': 'Can you bring towels to floor 2?',
        'responseRequested': true,
      }).encode(),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Accept request'));
    expect(find.text('Accept request'), findsOneWidget);
    expect(find.text('Decline request'), findsOneWidget);

    await tester.tap(find.text('Accept request'));
    await tester.pumpAndSettle();
    expect(find.text('Accept request?'), findsOneWidget);
    expect(
      find.textContaining('does not confirm that the work is complete'),
      findsOneWidget,
    );
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    final original = controller.notes.first;
    expect(original.workDecision, WorkDecision.accepted);
    expect(find.text('You accepted'), findsOneWidget);
    expect(find.text('Accept request'), findsNothing);
    expect(find.text('Decline request'), findsNothing);
    expect(
      controller.notes.where(
        (note) =>
            note.mine &&
            note.replyTo == original.id &&
            note.workDecision == WorkDecision.accepted,
      ),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await transport.stream.close();
    await location.stream.close();
  });
}
