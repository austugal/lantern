import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';

import 'fakes.dart';

Uint8List _photo() {
  final bytes = Uint8List(70);
  bytes.setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 13);
  bytes.setRange(12, 16, ascii.encode('IHDR'));
  data.setUint32(16, 1);
  data.setUint32(20, 1);
  return bytes;
}

class _ControlledTransport extends FakeTransport {
  String? holdKind;
  final pending = <Completer<void>>[];

  List<Packet> get attachments => calls
      .where((call) => call.$1 == 'send')
      .map((call) => Packet.decode(call.$2!['data'] as String))
      .whereType<Packet>()
      .where((packet) => packet.kind.startsWith('attachment'))
      .toList();

  @override
  Future<void> call(String method, [Map<String, dynamic>? args]) {
    if (method == 'send' &&
        holdKind != null &&
        Packet.decode(args!['data'] as String)?.kind == holdKind) {
      calls.add((method, args));
      final completion = Completer<void>();
      pending.add(completion);
      return completion.future;
    }
    return super.call(method, args);
  }
}

class _Session {
  final transport = _ControlledTransport();
  final location = FakeLocation();
  late final controller = LanternController(transport, location, FakeProfile());
  bool disposed = false;

  Future<void> open() async {
    await controller.initialize();
    await controller.start();
    await connect();
  }

  Future<void> connect() async {
    transport.emit('invitation');
    await controller.respond(true);
    transport.emit('connected');
  }

  void acknowledge(String id, {String peer = 'peer'}) => transport.emit(
    'data',
    id: peer,
    data: Packet('ack', newId(), {'id': id}).encode(),
  );

  Future<bool> send() => controller.sendAttachment(_photo(), 'image/png');

  void dispose() {
    controller.dispose();
    disposed = true;
  }

  Future<void> close() async {
    if (!disposed) {
      dispose();
    }
    await transport.stream.close();
    await location.stream.close();
  }
}

void _attachmentTest(
  String name,
  Future<void> Function(WidgetTester tester, _Session session) body,
) {
  testWidgets(name, (tester) async {
    final session = _Session();
    try {
      await session.open();
      await body(tester, session);
    } finally {
      await session.close();
    }
  });
}

void main() {
  _attachmentTest('receipt deadline starts after the final native submission', (
    tester,
    s,
  ) async {
    s.transport.holdKind = 'attachmentChunk';
    final sending = s.send();
    await tester.pump();
    final note = s.controller.notes.single;
    expect(s.transport.pending, hasLength(1));
    await tester.pump(const Duration(seconds: 9));
    expect(note.delivery, Delivery.sending);
    s.transport.pending.single.complete();
    await tester.pump();
    expect(await sending, isTrue);
    expect(note.delivery, Delivery.sent);
    await tester.pump(const Duration(seconds: 29));
    expect(note.delivery, Delivery.sent);
    await tester.pump(const Duration(seconds: 1));
    expect(note.delivery, Delivery.failed);
    expect(note.deliveryDetail, contains('receipt'));
    expect(s.controller.error, isEmpty);
  });

  _attachmentTest('missing receipt never retries an attachment automatically', (
    tester,
    s,
  ) async {
    expect(await s.send(), isTrue);
    final note = s.controller.notes.single;
    await tester.pump(LanternController.attachmentReceiptTimeout);
    expect(note.delivery, Delivery.failed);
    expect(note.deliveryDetail, isNotEmpty);
    expect(note.canRetry, isFalse);
    expect(s.controller.canRetry(note), isFalse);
    expect(await s.controller.retry(note), isFalse);
    await tester.pump(const Duration(minutes: 2));
    expect(s.transport.attachments, hasLength(2));
    expect(s.controller.notes.single, same(note));
  });

  _attachmentTest('matching receipt cancels the deadline and clears detail', (
    tester,
    s,
  ) async {
    expect(await s.send(), isTrue);
    final note = s.controller.notes.single;
    s.acknowledge(note.id);
    expect(note.delivery, Delivery.delivered);
    expect(note.deliveryDetail, isNull);
    var notifications = 0;
    s.controller.addListener(() => notifications++);
    await tester.pump(const Duration(seconds: 31));
    expect(note.delivery, Delivery.delivered);
    expect(notifications, 0);
  });

  _attachmentTest('late valid receipt recovers an unconfirmed attachment', (
    tester,
    s,
  ) async {
    expect(await s.send(), isTrue);
    final note = s.controller.notes.single;
    await tester.pump(LanternController.attachmentReceiptTimeout);
    expect(note.delivery, Delivery.failed);
    s.acknowledge(newId());
    s.acknowledge(note.id, peer: 'stranger');
    expect(note.delivery, Delivery.failed);
    s.acknowledge(note.id);
    expect(note.delivery, Delivery.delivered);
    expect(note.deliveryDetail, isNull);
    expect(s.controller.error, isEmpty);
  });

  _attachmentTest('another attachment does not replace an earlier deadline', (
    tester,
    s,
  ) async {
    expect(await s.send(), isTrue);
    final first = s.controller.notes.single;
    await tester.pump(const Duration(seconds: 15));
    expect(await s.send(), isTrue);
    final second = s.controller.notes.last;
    await tester.pump(const Duration(seconds: 15));
    expect(first.delivery, Delivery.failed);
    expect(second.delivery, Delivery.sent);
    s.acknowledge(second.id);
    await tester.pump(const Duration(seconds: 15));
    expect(first.delivery, Delivery.failed);
    expect(second.delivery, Delivery.delivered);
  });

  for (final result in ['completion', 'error', 'timeout']) {
    _attachmentTest('early receipt survives final native $result', (
      tester,
      s,
    ) async {
      s.transport.holdKind = 'attachmentChunk';
      final sending = s.send();
      await tester.pump();
      final note = s.controller.notes.single;
      s.acknowledge(note.id);
      expect(note.delivery, Delivery.delivered);
      if (result == 'error') {
        s.transport.pending.single.completeError(StateError('late failure'));
      } else if (result == 'completion') {
        s.transport.pending.single.complete();
      } else {
        await tester.pump(LanternController.attachmentSendTimeout);
      }
      await tester.pump();
      expect(await sending, isTrue);
      expect(note.delivery, Delivery.delivered);
      expect(note.deliveryDetail, isNull);
      expect(s.controller.error, isEmpty);
      expect(s.controller.sendingAttachment, isFalse);
      await tester.pump(const Duration(seconds: 31));
      expect(note.delivery, Delivery.delivered);
    });
  }

  _attachmentTest('native timeout fails visibly; a late receipt recovers it', (
    tester,
    s,
  ) async {
    s.transport.holdKind = 'attachmentChunk';
    final sending = s.send();
    await tester.pump();
    final note = s.controller.notes.single;
    await tester.pump(LanternController.attachmentSendTimeout);
    expect(await sending, isFalse);
    expect(note.delivery, Delivery.failed);
    expect(note.deliveryDetail, isNotEmpty);
    expect(s.controller.sendingAttachment, isFalse);
    s.controller.clearError();
    s.acknowledge(note.id);
    s.transport.pending.single.completeError(StateError('late native error'));
    await tester.pump();
    expect(note.delivery, Delivery.delivered);
    expect(note.deliveryDetail, isNull);
    expect(s.controller.error, isEmpty);
    expect(s.transport.attachments, hasLength(2));
  });

  for (final fail in [false, true]) {
    _attachmentTest(
      'previous session native ${fail ? 'error' : 'completion'} is inert',
      (tester, s) async {
        s.transport.holdKind = 'attachmentStart';
        final oldSending = s.send();
        await tester.pump();
        await s.controller.disconnect();
        await s.connect();
        s.transport.holdKind = null;
        expect(await s.send(), isTrue);
        final fresh = s.controller.notes.single;
        s.controller.clearError();
        if (fail) {
          s.transport.pending.single.completeError(StateError('stale failure'));
        } else {
          s.transport.pending.single.complete();
        }
        await tester.pump();
        expect(await oldSending, isFalse);
        expect(s.controller.notes.single, same(fresh));
        expect(fresh.delivery, Delivery.sent);
        expect(s.controller.error, isEmpty);
        expect(s.controller.sendingAttachment, isFalse);
        expect(s.transport.attachments, hasLength(3));
      },
    );
  }

  _attachmentTest('unresolved native budget survives timeouts and reconnects', (
    tester,
    s,
  ) async {
    s.transport.holdKind = 'attachmentStart';
    for (var i = 0; i < LanternController.maxPendingAttachmentSends; i++) {
      final sending = s.send();
      await tester.pump();
      await tester.pump(LanternController.attachmentSendTimeout);
      expect(await sending, isFalse);
    }
    expect(
      s.transport.pending,
      hasLength(LanternController.maxPendingAttachmentSends),
    );
    await s.controller.disconnect();
    await s.connect();
    expect(await s.send(), isFalse);
    expect(s.controller.notes, isEmpty);
    expect(
      s.transport.pending,
      hasLength(LanternController.maxPendingAttachmentSends),
    );
    s.transport.pending.first.complete();
    await tester.pump();
    s.transport.holdKind = null;
    expect(await s.send(), isTrue);
    expect(s.controller.notes, hasLength(1));
  });

  for (final end in ['disconnect', 'background', 'dispose']) {
    _attachmentTest('receipt timer is cancelled on $end', (tester, s) async {
      expect(await s.send(), isTrue);
      final old = s.controller.notes.single;
      if (end == 'disconnect') {
        await s.controller.disconnect();
      } else if (end == 'background') {
        s.controller.setForeground(false);
        await tester.pump();
      } else {
        s.dispose();
      }
      await tester.pump(const Duration(seconds: 31));
      expect(old.delivery, Delivery.sent);
      expect(old.deliveryDetail, isNull);
      expect(s.controller.error, isEmpty);
      if (end != 'dispose') {
        expect(s.controller.notes, isEmpty);
      }
    });
  }

  _attachmentTest('trimming cancels the attachment receipt timer', (
    tester,
    s,
  ) async {
    expect(await s.send(), isTrue);
    final old = s.controller.notes.single;
    for (var i = 0; i < 200; i++) {
      s.transport.emit(
        'data',
        data: Packet('text', newId(), {'text': 'Later note $i'}).encode(),
      );
    }
    expect(s.controller.notes, hasLength(200));
    expect(s.controller.notes.contains(old), isFalse);
    await tester.pump();
    var notifications = 0;
    s.controller.addListener(() => notifications++);
    await tester.pump(const Duration(seconds: 31));
    expect(old.delivery, Delivery.sent);
    expect(old.deliveryDetail, isNull);
    expect(notifications, 0);
  });
}
