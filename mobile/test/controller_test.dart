import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';
import 'package:lantern/src/services.dart';
import 'fakes.dart';

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
  });
  tearDown(() {
    c.dispose();
    transport.stream.close();
    location.stream.close();
  });
  Future<void> connect() async {
    transport.emit('invitation');
    await c.respond(true);
    transport.emit('connected');
  }

  test('discovery never automatically connects or accepts', () {
    transport.emit('found');
    expect(c.peers.length, 1);
    expect(
      transport.calls.where((v) => ['accept', 'request'].contains(v.$1)),
      isEmpty,
    );
    transport.emit('invitation');
    expect(c.invitation?.code, '1234');
    expect(c.connected, isNull);
  });
  test(
    'declined and unsolicited connections cannot receive messages',
    () async {
      transport.emit('invitation');
      await c.respond(false);
      transport.emit('connected');
      transport.emit(
        'data',
        data: Packet('text', newId(), {'text': 'Unwanted'}).encode(),
      );
      expect(c.connected, isNull);
      expect(c.notes, isEmpty);
      expect(transport.calls.any((v) => v.$1 == 'reject'), isTrue);
      expect(transport.calls.any((v) => v.$1 == 'disconnect'), isTrue);
    },
  );
  test('connection consent does not enable location', () async {
    await connect();
    expect(c.connected?.name, 'Alex');
    expect(c.sharing, isFalse);
    expect(location.stream.hasListener, isFalse);
  });
  test(
    'duplicates are acknowledged but displayed once; wrong endpoint ignored',
    () async {
      await connect();
      final packet = Packet('text', newId(), {'text': 'Hello'}).encode();
      transport.emit('data', id: 'stranger', data: packet);
      expect(c.notes, isEmpty);
      transport.emit('data', data: packet);
      transport.emit('data', data: packet);
      expect(c.notes.length, 1);
      expect(transport.calls.where((v) => v.$1 == 'send').length, 2);
    },
  );
  test(
    'sent does not mean delivered; only matching receipt confirms delivery',
    () async {
      await connect();
      await c.send('Hello');
      expect(c.notes.single.delivery, Delivery.sent);
      transport.emit(
        'data',
        data: Packet('ack', newId(), {'id': newId()}).encode(),
      );
      expect(c.notes.single.delivery, Delivery.sent);
      transport.emit(
        'data',
        data: Packet('ack', newId(), {'id': c.notes.single.id}).encode(),
      );
      expect(c.notes.single.delivery, Delivery.delivered);
    },
  );
  test('failed sends remain visibly failed', () async {
    await connect();
    transport.failMethod = 'send';
    expect(await c.send('Hello'), isFalse);
    expect(c.notes.single.delivery, Delivery.failed);
  });
  test(
    'location requires opt in and stops immediately on background',
    () async {
      await connect();
      await c.startSharing();
      expect(c.sharing, isTrue);
      location.stream.add(const Fix(38.6, -9.1, 10));
      expect(transport.calls.where((v) => v.$1 == 'send').length, 1);
      c.setForeground(false);
      expect(c.sharing, isFalse);
      expect(c.connected, isNull);
      expect(c.active, isFalse);
      location.stream.add(const Fix(39, -9, 10));
      expect(transport.calls.where((v) => v.$1 == 'send').length, 1);
      c.setForeground(true);
      expect(c.active, isFalse);
    },
  );
  test(
    'permission resolution cannot restart sharing after disconnect',
    () async {
      await connect();
      location.permission = Completer<void>();
      final operation = c.startSharing();
      await c.disconnect();
      location.permission!.complete();
      await operation;
      expect(c.sharing, isFalse);
      expect(location.stream.hasListener, isFalse);
    },
  );
  test('stop sharing sends revocation and clears remote location', () async {
    await connect();
    await c.startSharing();
    await c.stopSharing();
    expect(c.sharing, isFalse);
    final sent =
        transport.calls.where((v) => v.$1 == 'send').last.$2!['data'] as String;
    expect(Packet.decode(sent)?.kind, 'locationStop');
    transport.emit(
      'data',
      data: Packet('location', newId(), {
        'lat': 38.6,
        'lon': -9.1,
        'accuracy': 10,
      }).encode(),
    );
    expect(c.remoteLocation, isNotNull);
    transport.emit('data', data: Packet('locationStop', newId(), {}).encode());
    expect(c.remoteLocation, isNull);
  });
  testWidgets('sharing automatically stops after 15 minutes', (tester) async {
    final t = FakeTransport();
    final l = FakeLocation();
    final timed = LanternController(t, l, FakeProfile());
    await timed.initialize();
    await timed.start();
    t.emit('invitation');
    await timed.respond(true);
    t.emit('connected');
    await timed.startSharing();
    expect(timed.sharing, isTrue);
    await tester.pump(const Duration(minutes: 15));
    expect(timed.sharing, isFalse);
    timed.dispose();
    await t.stream.close();
    await l.stream.close();
  });
  test(
    'disconnect clears the session and late events cannot restore it',
    () async {
      await connect();
      await c.send('Private');
      await c.stop();
      transport.emit('connected');
      expect(c.notes, isEmpty);
      expect(c.connected, isNull);
      expect(c.invitation, isNull);
    },
  );
}
