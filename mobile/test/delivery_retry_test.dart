import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';

import 'fakes.dart';

class _ControlledTransport extends FakeTransport {
  bool holdText = false;
  final submissions = <Completer<void>>[];

  List<Packet> get texts => calls
      .where((call) => call.$1 == 'send')
      .map((call) => Packet.decode(call.$2!['data'] as String))
      .whereType<Packet>()
      .where((packet) => packet.kind == 'text')
      .toList();

  List<Packet> get receipts => calls
      .where((call) => call.$1 == 'send')
      .map((call) => Packet.decode(call.$2!['data'] as String))
      .whereType<Packet>()
      .where((packet) => packet.kind == 'ack')
      .toList();

  @override
  Future<void> call(String method, [Map<String, dynamic>? args]) {
    if (method == 'send' &&
        holdText &&
        Packet.decode(args!['data'] as String)?.kind == 'text') {
      calls.add((method, args));
      final completion = Completer<void>();
      submissions.add(completion);
      return completion.future;
    }
    return super.call(method, args);
  }
}

class _Session {
  final transport = _ControlledTransport();
  final location = FakeLocation();
  late final controller = LanternController(transport, location, FakeProfile());

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

  void acknowledge(String id) =>
      transport.emit('data', data: Packet('ack', newId(), {'id': id}).encode());

  void receive(String id, String text) =>
      transport.emit('data', data: Packet('text', id, {'text': text}).encode());

  Future<void> close() async {
    controller.dispose();
    await transport.stream.close();
    await location.stream.close();
  }
}

void _deliveryTest(
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
  _deliveryTest('native timeout is bounded and never automatically resubmits', (
    tester,
    s,
  ) async {
    s.transport.holdText = true;
    final submitted = s.controller.send('Keep this text');
    final note = s.controller.notes.single;
    expect(note.delivery, Delivery.sending);
    await tester.pump(const Duration(seconds: 9));
    expect(note.delivery, Delivery.sending);
    await tester.pump(const Duration(seconds: 1));
    expect(await submitted, isFalse);
    expect(note.delivery, Delivery.failed);
    expect(note.deliveryDetail, contains('timed out'));
    expect(s.controller.error, isEmpty);
    expect(s.controller.canRetry(note), isTrue);
    await tester.pump(const Duration(minutes: 2));
    expect(s.transport.texts, hasLength(1));
    expect(note.sendAttempts, 1);
  });

  _deliveryTest('receipt deadline starts after native submission finishes', (
    tester,
    s,
  ) async {
    s.transport.holdText = true;
    final submitted = s.controller.send('Wait for receipt');
    final note = s.controller.notes.single;
    await tester.pump(const Duration(seconds: 9));
    s.transport.submissions.single.complete();
    await tester.pump();
    expect(await submitted, isTrue);
    expect(note.delivery, Delivery.sent);
    await tester.pump(const Duration(seconds: 29));
    expect(note.delivery, Delivery.sent);
    await tester.pump(const Duration(seconds: 1));
    expect(note.delivery, Delivery.failed);
    expect(note.deliveryDetail, contains('No text receipt'));
    expect(s.controller.error, isEmpty);
    expect(s.controller.canRetry(note), isTrue);
  });

  _deliveryTest(
    'manual retry preserves identity and stops at three submissions',
    (tester, s) async {
      s.transport.failMethod = 'send';
      expect(await s.controller.send('Original text'), isFalse);
      final note = s.controller.notes.single;
      final created = note.time;
      expect(await s.controller.retry(note), isFalse);
      expect(await s.controller.retry(note), isFalse);
      expect(note.sendAttempts, LanternController.maxTextSubmissions);
      expect(note.canRetry, isFalse);
      expect(await s.controller.retry(note), isFalse);
      expect(s.controller.notes.single, same(note));
      expect(note.time, created);
      expect(s.transport.texts, hasLength(3));
      expect(s.transport.texts.map((packet) => packet.id).toSet(), {note.id});
      expect(s.transport.texts.map((packet) => packet.body['text']).toSet(), {
        'Original text',
      });
      await tester.pump(const Duration(minutes: 2));
      expect(s.transport.texts, hasLength(3));
    },
  );

  _deliveryTest('retry excludes disappearing text and attachments', (
    tester,
    s,
  ) async {
    s.transport.failMethod = 'send';
    s.controller.setMessageLifetime(60);
    expect(await s.controller.send('Temporary'), isFalse);
    expect(s.controller.notes.single.canRetry, isFalse);
    expect(s.controller.canRetry(s.controller.notes.single), isFalse);
    final media = Note(
      newId(),
      'Photo',
      true,
      DateTime.now(),
      Delivery.failed,
      attachmentBytes: Uint8List.fromList([1]),
      attachmentMime: 'image/png',
    )..sendAttempts = 1;
    expect(media.canRetry, isFalse);
  });

  _deliveryTest('late receipt confirms a timed out native call', (
    tester,
    s,
  ) async {
    s.transport.holdText = true;
    final submitted = s.controller.send('May already be there');
    final note = s.controller.notes.single;
    await tester.pump(LanternController.textSendTimeout);
    expect(await submitted, isFalse);
    expect(note.delivery, Delivery.failed);
    s.acknowledge(note.id);
    expect(note.delivery, Delivery.delivered);
    expect(note.deliveryDetail, isNull);
    expect(s.controller.error, isEmpty);
    s.transport.submissions.single.completeError(StateError('late failure'));
    await tester.pump();
    expect(note.delivery, Delivery.delivered);
    expect(note.deliveryDetail, isNull);
    expect(s.controller.error, isEmpty);
  });

  for (final fail in [false, true]) {
    _deliveryTest(
      'old attempt ${fail ? 'error' : 'success'} cannot overwrite retry',
      (tester, s) async {
        s.transport.holdText = true;
        final first = s.controller.send('Stable retry');
        final note = s.controller.notes.single;
        await tester.pump(LanternController.textSendTimeout);
        expect(await first, isFalse);
        s.transport.holdText = false;
        expect(await s.controller.retry(note), isTrue);
        expect(note.delivery, Delivery.sent);
        if (fail) {
          s.transport.submissions.single.completeError(StateError('old error'));
        } else {
          s.transport.submissions.single.complete();
        }
        await tester.pump();
        expect(note.delivery, Delivery.sent);
        expect(s.controller.error, isEmpty);
        s.acknowledge(note.id);
        expect(note.delivery, Delivery.delivered);
      },
    );
  }

  for (final fail in [false, true]) {
    _deliveryTest('old session native ${fail ? 'error' : 'success'} is inert', (
      tester,
      s,
    ) async {
      s.transport.holdText = true;
      unawaited(s.controller.send('Old session'));
      await s.controller.disconnect();
      await s.connect();
      s.transport.holdText = false;
      expect(await s.controller.send('New session'), isTrue);
      final fresh = s.controller.notes.single;
      s.controller.clearError();
      if (fail) {
        s.transport.submissions.single.completeError(StateError('stale'));
      } else {
        s.transport.submissions.single.complete();
      }
      await tester.pump();
      expect(s.controller.notes.single, same(fresh));
      expect(fresh.delivery, Delivery.sent);
      expect(s.controller.error, isEmpty);
    });
  }

  _deliveryTest('only eight unconfirmed receipt attempts are admitted', (
    tester,
    s,
  ) async {
    for (var i = 0; i < LanternController.maxPendingTextSends; i++) {
      expect(await s.controller.send('Pending $i'), isTrue);
    }
    expect(
      s.controller.notes,
      hasLength(LanternController.maxPendingTextSends),
    );
    expect(await s.controller.send('Rejected before admission'), isFalse);
    expect(
      s.controller.notes,
      hasLength(LanternController.maxPendingTextSends),
    );
    s.acknowledge(s.controller.notes.first.id);
    expect(await s.controller.send('Now admitted'), isTrue);
  });

  _deliveryTest('unresolved native call budget survives reconnect', (
    tester,
    s,
  ) async {
    s.transport.holdText = true;
    final submissions = <Future<bool>>[];
    for (var i = 0; i < LanternController.maxPendingTextSends; i++) {
      submissions.add(s.controller.send('Hung $i'));
    }
    await tester.pump(LanternController.textSendTimeout);
    for (final submission in submissions) {
      expect(await submission, isFalse);
    }
    await s.controller.disconnect();
    await s.connect();
    expect(await s.controller.send('Still bounded'), isFalse);
    expect(s.controller.notes, isEmpty);
    s.transport.submissions.first.complete();
    await tester.pump();
    s.transport.holdText = false;
    expect(await s.controller.send('Slot released'), isTrue);
    expect(s.controller.notes, hasLength(1));
  });

  _deliveryTest('text dedup survives mixed traffic and note trimming', (
    tester,
    s,
  ) async {
    final original = newId();
    s.receive(original, 'Original');
    for (var i = 0; i < 600; i++) {
      s.transport.emit(
        'data',
        data: Packet('locationStop', newId(), {}).encode(),
      );
    }
    for (var i = 0; i < 200; i++) {
      s.receive(newId(), 'Later $i');
    }
    expect(s.controller.notes, hasLength(200));
    expect(s.controller.notes.any((note) => note.id == original), isFalse);
    final receiptsBefore = s.transport.receipts.length;
    s.receive(original, 'Original');
    expect(s.controller.notes, hasLength(200));
    expect(s.controller.notes.any((note) => note.id == original), isFalse);
    expect(s.transport.receipts, hasLength(receiptsBefore + 1));
  });

  _deliveryTest('accepted text ledger is bounded and resets on reconnect', (
    tester,
    s,
  ) async {
    for (var i = 0; i < 1024; i++) {
      s.receive(i.toRadixString(16).padLeft(32, '0'), 'Text $i');
    }
    final overflow = List.filled(32, 'f').join();
    final receiptsBefore = s.transport.receipts.length;
    s.receive(overflow, 'Overflow');
    expect(s.transport.receipts, hasLength(receiptsBefore));
    expect(s.controller.notes.any((note) => note.id == overflow), isFalse);
    expect(s.controller.error, contains('Reconnect'));
    await s.controller.disconnect();
    await s.connect();
    s.receive(overflow, 'Accepted after reconnect');
    expect(s.transport.receipts, hasLength(receiptsBefore + 1));
    expect(s.controller.notes.single.id, overflow);
  });
}
