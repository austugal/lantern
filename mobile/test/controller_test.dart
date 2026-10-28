import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';
import 'package:lantern/src/services.dart';
import 'fakes.dart';

class _DelayedTransport extends FakeTransport {
  final heldMethods = <String>{};
  final pending = <String, Completer<void>>{};

  @override
  Future<void> call(String method, [Map<String, dynamic>? args]) {
    if (heldMethods.contains(method)) {
      calls.add((method, args));
      final completion = Completer<void>();
      pending[method] = completion;
      return completion.future;
    }
    return super.call(method, args);
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
  test('background interruption requires explicit discovery restart', () async {
    await connect();
    await c.send('Memory-only session');
    await c.startSharing();
    final starts = transport.calls.where((call) => call.$1 == 'start').length;

    c.setForeground(false);
    expect(c.reconnectReason, ReconnectReason.backgrounded);
    expect(c.reconnectPeerName, 'Alex');
    expect(c.restartNeeded, isTrue);
    expect(c.active, isFalse);
    expect(c.connected, isNull);
    expect(c.notes, isEmpty);
    expect(c.sharing, isFalse);

    // Native shutdown can arrive after the Dart lifecycle callback. It must
    // preserve the more useful explanation of why this session ended.
    transport.emit('stopped');
    expect(c.reconnectReason, ReconnectReason.backgrounded);
    c.setForeground(true);
    expect(c.restartNeeded, isTrue);
    expect(c.active, isFalse);
    expect(transport.calls.where((call) => call.$1 == 'start').length, starts);
    expect(transport.calls.where((call) => call.$1 == 'accept').length, 1);

    await c.start();
    expect(c.active, isTrue);
    expect(c.reconnectReason, isNull);
    expect(c.restartNeeded, isFalse);
    expect(c.connected, isNull);
    expect(c.sharing, isFalse);
  });

  test(
    'backgrounding an already stopped Lantern creates no restart notice',
    () async {
      await c.stop();
      c.setForeground(false);
      c.setForeground(true);
      expect(c.reconnectReason, isNull);
      expect(c.restartNeeded, isFalse);
      expect(c.active, isFalse);
      expect(transport.calls.where((call) => call.$1 == 'start').length, 1);
    },
  );

  test(
    'intentional stop and its native completion create no interruption notice',
    () async {
      await connect();
      await c.stop();
      transport.emit('stopped');
      expect(c.reconnectReason, isNull);
      expect(c.restartNeeded, isFalse);
      expect(c.connected, isNull);
      expect(c.active, isFalse);
    },
  );

  test(
    'intentional disconnect and its native event create no interruption notice',
    () async {
      await connect();
      await c.disconnect();
      transport.emit('disconnected');
      expect(c.reconnectReason, isNull);
      expect(c.restartNeeded, isFalse);
      expect(c.connected, isNull);
      expect(c.active, isTrue);
    },
  );

  test(
    'unexpected native stop preserves peer context without restarting',
    () async {
      await connect();
      transport.emit('stopped');
      expect(c.reconnectReason, ReconnectReason.nativeStopped);
      expect(c.reconnectPeerName, 'Alex');
      expect(c.restartNeeded, isTrue);
      expect(c.active, isFalse);
      expect(c.connected, isNull);
      c.setForeground(true);
      transport.emit('connected');
      expect(c.connected, isNull);
      expect(transport.calls.where((call) => call.$1 == 'start').length, 1);
      await c.start();
      expect(c.active, isTrue);
      expect(c.reconnectReason, isNull);
    },
  );

  test(
    'native stop clears an invitation and requires a fresh invitation',
    () async {
      transport.emit('invitation');
      expect(c.invitation, isNotNull);
      transport.emit('stopped');
      expect(c.reconnectReason, ReconnectReason.nativeStopped);
      expect(c.reconnectPeerName, 'Alex');
      expect(c.invitation, isNull);
      expect(c.requesting, isNull);
      expect(c.restartNeeded, isTrue);
      await c.respond(true);
      expect(transport.calls.where((call) => call.$1 == 'accept'), isEmpty);
      await c.start();
      transport.emit('connected');
      expect(c.connected, isNull);
      expect(c.reconnectReason, isNull);
    },
  );

  test(
    'failed explicit restart retains the interruption recovery notice',
    () async {
      transport.emit('stopped');
      transport.failMethod = 'start';
      await c.start();
      expect(c.active, isFalse);
      expect(c.busy, isFalse);
      expect(c.reconnectReason, ReconnectReason.nativeStopped);
      expect(c.restartNeeded, isTrue);
      expect(c.error, contains('Transport failed'));
      transport.failMethod = null;
      await c.start();
      expect(c.active, isTrue);
      expect(c.reconnectReason, isNull);
    },
  );

  test(
    'native stop during pending start cannot be undone by late completion',
    () async {
      final delayed = _DelayedTransport();
      final source = FakeLocation();
      final controller = LanternController(delayed, source, FakeProfile());
      try {
        await controller.initialize();
        delayed.heldMethods.add('start');
        final starting = controller.start();
        expect(controller.busy, isTrue);
        delayed.emit('stopped');
        expect(controller.reconnectReason, ReconnectReason.nativeStopped);
        expect(controller.restartNeeded, isTrue);
        delayed.pending['start']!.complete();
        await starting;
        expect(controller.active, isFalse);
        expect(controller.busy, isFalse);
        expect(controller.restartNeeded, isTrue);
        controller.setForeground(true);
        expect(delayed.calls.where((call) => call.$1 == 'start').length, 1);
        delayed.heldMethods.clear();
        await controller.start();
        expect(controller.active, isTrue);
        expect(controller.reconnectReason, isNull);
      } finally {
        controller.dispose();
        await delayed.stream.close();
        await source.stream.close();
      }
    },
  );

  test(
    'peer disconnect requires fresh consent and never restores private state',
    () async {
      await connect();
      await c.send('Old conversation');
      await c.startSharing();
      transport.emit('disconnected');
      expect(c.reconnectReason, ReconnectReason.peerDisconnected);
      expect(c.reconnectPeerName, 'Alex');
      expect(c.active, isTrue);
      expect(c.notes, isEmpty);
      expect(c.sharing, isFalse);
      expect(c.connected, isNull);
      final accepts = transport.calls
          .where((call) => call.$1 == 'accept')
          .length;

      transport.emit('connected');
      transport.emit(
        'data',
        data: Packet('text', newId(), {
          'text': 'Without renewed consent',
        }).encode(),
      );
      expect(c.connected, isNull);
      expect(c.notes, isEmpty);
      expect(
        transport.calls.where((call) => call.$1 == 'accept').length,
        accepts,
      );
      transport.emit('invitation', code: '5678');
      expect(c.invitation?.code, '5678');
      expect(c.connected, isNull);
      await c.respond(true);
      transport.emit('connected');
      expect(c.connected?.name, 'Alex');
      expect(c.reconnectReason, isNull);
      expect(c.notes, isEmpty);
      expect(c.sharing, isFalse);
      expect(c.guardianAccepted, isFalse);
      expect(c.checkInUntil, isNull);
    },
  );

  test(
    'unrelated peer disconnect does not interrupt the current session',
    () async {
      await connect();
      transport.emit('disconnected', id: 'stranger');
      expect(c.connected?.id, 'peer');
      expect(c.reconnectReason, isNull);
      expect(c.restartNeeded, isFalse);
    },
  );

  test('dismissing interruption notice does not enable discovery', () async {
    transport.emit('stopped');
    c.dismissReconnectNotice();
    expect(c.reconnectReason, isNull);
    expect(c.active, isFalse);
    expect(c.connected, isNull);
    expect(transport.calls.where((call) => call.$1 == 'start').length, 1);
  });

  test(
    'old native request failure cannot clear a new connection request',
    () async {
      final delayed = _DelayedTransport();
      final source = FakeLocation();
      final controller = LanternController(delayed, source, FakeProfile());
      try {
        await controller.initialize();
        await controller.start();
        delayed.heldMethods.add('request');
        final oldRequest = controller.request(
          const Peer('old-peer', 'Old peer'),
        );
        expect(controller.requesting, 'old-peer');
        await controller.disconnect();
        delayed.heldMethods.clear();
        await controller.request(const Peer('new-peer', 'New peer'));
        expect(controller.requesting, 'new-peer');
        delayed.pending['request']!.completeError(
          StateError('Old request failed'),
        );
        await oldRequest;
        expect(controller.requesting, 'new-peer');
        expect(controller.error, isEmpty);
        expect(controller.reconnectReason, isNull);
      } finally {
        controller.dispose();
        await delayed.stream.close();
        await source.stream.close();
      }
    },
  );

  for (final accept in [true, false]) {
    test(
      'old native ${accept ? 'accept' : 'reject'} failure cannot disconnect a new session',
      () async {
        final delayed = _DelayedTransport();
        final source = FakeLocation();
        final controller = LanternController(delayed, source, FakeProfile());
        try {
          await controller.initialize();
          await controller.start();
          final method = accept ? 'accept' : 'reject';
          delayed.heldMethods.add(method);
          delayed.emit('invitation', id: 'old-peer', name: 'Old peer');
          final oldResponse = controller.respond(accept);
          await controller.disconnect();
          delayed.heldMethods.clear();
          delayed.emit(
            'invitation',
            id: 'new-peer',
            name: 'New peer',
            code: '5678',
          );
          await controller.respond(true);
          delayed.emit('connected', id: 'new-peer', name: 'New peer');
          expect(controller.connected?.id, 'new-peer');
          final disconnects = delayed.calls
              .where((call) => call.$1 == 'disconnect')
              .length;
          delayed.pending[method]!.completeError(
            StateError('Old response failed'),
          );
          await oldResponse;
          expect(controller.connected?.id, 'new-peer');
          expect(controller.error, isEmpty);
          expect(controller.reconnectReason, isNull);
          expect(
            delayed.calls.where((call) => call.$1 == 'disconnect').length,
            disconnects,
          );
        } finally {
          controller.dispose();
          await delayed.stream.close();
          await source.stream.close();
        }
      },
    );
  }
}
