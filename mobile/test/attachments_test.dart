import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';
import 'fakes.dart';

Uint8List photo([int size = 70]) {
  final bytes = Uint8List(size);
  bytes.setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 13);
  bytes.setRange(12, 16, ascii.encode('IHDR'));
  data.setUint32(16, 1);
  data.setUint32(20, 1);
  return bytes;
}

class BlockingTransport extends FakeTransport {
  Completer<void>? sendGate;
  @override
  Future<void> call(String method, [Map<String, dynamic>? args]) async {
    await super.call(method, args);
    if (method == 'send') {
      await sendGate?.future;
    }
  }
}

void main() {
  late FakeTransport transport;
  late FakeLocation location;
  late LanternController c;
  setUp(() async {
    transport = FakeTransport();
    location = FakeLocation();
    c = LanternController(transport, location, FakeProfile());
    await c.initialize();
    await c.start();
    transport.emit('invitation');
    await c.respond(true);
    transport.emit('connected');
  });
  tearDown(() async {
    c.dispose();
    await transport.stream.close();
    await location.stream.close();
  });
  void receive(Packet packet, {String peer = 'peer'}) =>
      transport.emit('data', id: peer, data: packet.encode());
  Packet start(String id, Uint8List bytes, {String mime = 'image/png'}) =>
      Packet('attachmentStart', id, {
        'mime': mime,
        'size': bytes.length,
        'chunks':
            (bytes.length + attachmentChunkBytes - 1) ~/ attachmentChunkBytes,
      });
  Packet chunk(String id, int index, Uint8List bytes) => Packet(
    'attachmentChunk',
    newId(),
    {'transfer': id, 'index': index, 'data': base64Encode(bytes)},
  );

  test('metadata and chunks reject oversize or unrecognized inputs', () {
    expect(
      Packet.decode(start(newId(), Uint8List(maxAttachmentBytes + 1)).encode()),
      isNull,
    );
    expect(
      Packet.decode(start(newId(), photo(), mime: 'text/html').encode()),
      isNull,
    );
    expect(
      Packet.decode(
        Packet('attachmentStart', newId(), {
          'mime': 'image/png',
          'size': 70,
          'chunks': 2,
        }).encode(),
      ),
      isNull,
    );
    expect(Packet.decode(chunk(newId(), 256, photo()).encode()), isNull);
    expect(
      Packet.decode(
        Packet('attachmentChunk', newId(), {
          'transfer': newId(),
          'index': 0,
          'data': 'not base64!',
        }).encode(),
      ),
      isNull,
    );
    expect(Packet.decode(chunk(newId(), 0, Uint8List(4097)).encode()), isNull);
    final packet = chunk(newId(), 0, Uint8List(4096));
    expect(utf8.encode(packet.encode()).length, lessThan(Packet.maxBytes));
    expect(Packet.decode(packet.encode()), isNotNull);
  });

  test('media signatures and unsafe image dimensions are rejected', () {
    expect(validAttachment(photo(), 'image/png'), isTrue);
    expect(validAttachment(Uint8List(70), 'image/png'), isFalse);
    final huge = photo();
    ByteData.sublistView(huge).setUint32(16, 100000);
    expect(validAttachment(huge, 'image/png'), isFalse);
    final audio = Uint8List(32);
    ByteData.sublistView(audio).setUint32(0, 24);
    audio.setRange(4, 8, ascii.encode('ftyp'));
    audio.setRange(8, 12, ascii.encode('M4A '));
    expect(validAttachment(audio, 'audio/mp4'), isTrue);
    expect(validAttachment(audio, 'image/jpeg'), isFalse);
  });

  test(
    'out of order chunks display and acknowledge only complete attachment',
    () {
      final bytes = photo(5000);
      final id = newId();
      final received = <Note>[];
      c.onNoteReceived = received.add;
      receive(start(id, bytes));
      receive(chunk(id, 1, bytes.sublist(4096)));
      expect(c.notes, isEmpty);
      expect(transport.calls.where((call) => call.$1 == 'send'), isEmpty);
      receive(chunk(id, 0, bytes.sublist(0, 4096)));
      expect(c.notes.single.attachmentBytes, orderedEquals(bytes));
      expect(c.notes.single.attachmentKind, 'photo');
      expect(received.length, 1);
      final ack = Packet.decode(transport.calls.last.$2!['data'] as String)!;
      expect(ack.kind, 'ack');
      expect(ack.body['id'], id);
      receive(chunk(id, 1, bytes.sublist(4096)));
      expect(c.notes.length, 1);
      expect(received.length, 1);
    },
  );

  test('wrong endpoint, short chunk and bad signature never get a receipt', () {
    final bytes = photo(5000);
    final id = newId();
    receive(start(id, bytes), peer: 'stranger');
    receive(chunk(id, 0, bytes.sublist(0, 4096)));
    receive(start(id, bytes));
    receive(chunk(id, 0, bytes.sublist(0, 4000)));
    receive(chunk(id, 1, bytes.sublist(4096)));
    final invalidId = newId();
    final invalid = Uint8List(70);
    receive(start(invalidId, invalid));
    receive(chunk(invalidId, 0, invalid));
    expect(c.notes, isEmpty);
    expect(transport.calls.where((call) => call.$1 == 'send'), isEmpty);
  });

  test(
    'partial transfers are capped at two and cleared on disconnect',
    () async {
      final bytes = photo();
      final first = newId(), second = newId(), third = newId();
      receive(start(first, bytes));
      receive(start(second, bytes));
      receive(start(third, bytes));
      receive(chunk(third, 0, bytes));
      expect(c.notes, isEmpty);
      await c.disconnect();
      transport.emit('invitation');
      await c.respond(true);
      transport.emit('connected');
      receive(chunk(first, 0, bytes));
      expect(c.notes, isEmpty);
      receive(start(third, bytes));
      receive(chunk(third, 0, bytes));
      expect(c.notes.length, 1);
    },
  );

  test('conflicting duplicate chunk discards transfer', () {
    final bytes = photo(5000), id = newId();
    receive(start(id, bytes));
    receive(chunk(id, 0, bytes.sublist(0, 4096)));
    receive(chunk(id, 0, Uint8List(4096)));
    receive(chunk(id, 1, bytes.sublist(4096)));
    expect(c.notes, isEmpty);
  });

  test(
    'sender chunks with expiry and waits for matching complete receipt',
    () async {
      c.setMessageLifetime(60);
      expect(await c.sendAttachment(photo(5000), 'image/png'), isTrue);
      expect(c.sendingAttachment, isFalse);
      expect(c.notes.single.delivery, Delivery.sent);
      final packets = transport.calls
          .where((call) => call.$1 == 'send')
          .map((call) => Packet.decode(call.$2!['data'] as String)!)
          .toList();
      expect(packets.map((packet) => packet.kind), [
        'attachmentStart',
        'attachmentChunk',
        'attachmentChunk',
      ]);
      expect(packets.first.body['ttl'], 60);
      receive(Packet('ack', newId(), {'id': c.notes.single.id}));
      expect(c.notes.single.delivery, Delivery.delivered);
      expect(c.notes.single.expiresAt, isNotNull);
    },
  );

  test('failed native send marks attachment failed', () async {
    transport.failMethod = 'send';
    expect(await c.sendAttachment(photo(), 'image/png'), isFalse);
    expect(c.notes.single.delivery, Delivery.failed);
    expect(c.sendingAttachment, isFalse);
  });

  test('disconnect during native send prevents subsequent chunks', () async {
    final t = BlockingTransport(), l = FakeLocation();
    final controller = LanternController(t, l, FakeProfile());
    await controller.initialize();
    await controller.start();
    t.emit('invitation');
    await controller.respond(true);
    t.emit('connected');
    t.sendGate = Completer<void>();
    final send = controller.sendAttachment(photo(5000), 'image/png');
    await Future<void>.delayed(Duration.zero);
    await controller.disconnect();
    t.sendGate!.complete();
    expect(await send, isFalse);
    expect(t.calls.where((call) => call.$1 == 'send').length, 1);
    expect(controller.notes, isEmpty);
    expect(controller.sendingAttachment, isFalse);
    controller.dispose();
    await t.stream.close();
    await l.stream.close();
  });
}
