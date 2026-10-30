import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/app.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';
import 'fakes.dart';

void main() {
  testWidgets('unconfirmed attachment is visible without a retry control', (
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
    final voice = Uint8List(32);
    ByteData.sublistView(voice).setUint32(0, 24);
    voice.setRange(4, 8, ascii.encode('ftyp'));
    voice.setRange(8, 12, ascii.encode('M4A '));
    expect(await controller.sendAttachment(voice, 'audio/mp4'), isTrue);
    await tester.pumpWidget(LanternApp(controller: controller));
    await tester.tap(find.text('Conversation'));
    await tester.pumpAndSettle();
    expect(find.text('Sent · awaiting receipt'), findsOneWidget);
    await tester.pump(LanternController.attachmentReceiptTimeout);
    expect(find.text('Delivery unconfirmed'), findsOneWidget);
    expect(find.textContaining('may already have arrived'), findsOneWidget);
    expect(find.text('Retry message'), findsNothing);
    transport.emit(
      'data',
      data: Packet('ack', newId(), {'id': controller.notes.single.id}).encode(),
    );
    await tester.pump();
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Delivery unconfirmed'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await transport.stream.close();
    await location.stream.close();
  });
}
