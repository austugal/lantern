import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';
import 'package:lantern/src/navigation.dart';
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
    transport.emit('invitation');
    await c.respond(true);
    transport.emit('connected');
  });
  tearDown(() async {
    c.dispose();
    await transport.stream.close();
    await location.stream.close();
  });
  void receive(String kind, Map<String, dynamic> body) =>
      transport.emit('data', data: Packet(kind, newId(), body).encode());

  test('disappearing message expiry travels with message', () async {
    c.setMessageLifetime(60);
    await c.send('Temporary');
    final packet = Packet.decode(transport.calls.last.$2!['data'] as String)!;
    expect(packet.body['ttl'], 60);
    expect(c.notes.single.expiresAt, isNotNull);
    receive('text', {'text': 'Also temporary', 'ttl': 300});
    expect(c.notes.last.expiresAt, isNotNull);
    expect(
      Packet.decode(
        Packet('text', newId(), {'text': 'bad', 'ttl': -1}).encode(),
      ),
      isNull,
    );
    c.setMessageLifetime(2);
    expect(c.messageLifetimeSeconds, 60);
  });
  test(
    'guardian permission is separate and unsolicited acceptance ignored',
    () async {
      receive('guardianResponse', {'accepted': true});
      expect(c.guardianAccepted, isFalse);
      await c.sendSos();
      expect(transport.calls.where((call) => call.$1 == 'send'), isEmpty);
      await c.requestGuardian();
      receive('guardianResponse', {'accepted': true});
      expect(c.guardianAccepted, isTrue);
      c.armCheckIn(const Duration(minutes: 5));
      expect(c.checkInUntil, isNotNull);
      await c.sendSos();
      expect(c.guardianStatus, contains('receipt not confirmed'));
      expect(c.sharing, isFalse);
      c.setForeground(false);
      expect(c.checkInUntil, isNull);
      expect(c.guardianAccepted, isFalse);
    },
  );
  test('alerts ignored unless local peer agreed to guardian role', () async {
    receive('guardianAlert', {});
    expect(c.incomingAlert, isEmpty);
    receive('guardianRequest', {});
    expect(c.guardianRequested, isTrue);
    await c.respondGuardian(true);
    receive('guardianAlert', {});
    expect(c.incomingAlert, contains('assistance'));
  });
  test(
    'local navigation never sends position and rejects malformed fixes',
    () async {
      await c.startNavigation();
      location.stream.add(const Fix(0, 0, 5));
      location.stream.add(const Fix(91, 0, 5));
      expect(c.breadcrumbs.length, 1);
      c.saveWaypoint('Start');
      expect(c.waypoints.length, 1);
      location.stream.add(const Fix(0, 0.001, 5));
      expect(
        c.navigationTo(c.waypoints['Start']!)!.distanceMeters,
        closeTo(111.2, 1),
      );
      expect(transport.calls.where((call) => call.$1 == 'send'), isEmpty);
      c.setForeground(false);
      expect(c.navigating, isFalse);
      expect(c.localFix, isNull);
      c.clearTrail();
      expect(c.waypoints, isEmpty);
      expect(c.breadcrumbs, isEmpty);
    },
  );
  test('late GPS permission cannot restart a background session', () async {
    location.permission = Completer<void>();
    final operation = c.startNavigation();
    c.setForeground(false);
    location.permission!.complete();
    await operation;
    expect(c.navigating, isFalse);
  });
  testWidgets('guardian request times out and late acceptance is ignored', (
    tester,
  ) async {
    final t = FakeTransport();
    final l = FakeLocation();
    final timed = LanternController(t, l, FakeProfile());
    await timed.initialize();
    await timed.start();
    t.emit('invitation');
    await timed.respond(true);
    t.emit('connected');
    await timed.requestGuardian();
    await tester.pump(const Duration(seconds: 35));
    expect(timed.guardianStatus, contains('expired'));
    t.emit(
      'data',
      data: Packet('guardianResponse', newId(), {'accepted': true}).encode(),
    );
    expect(timed.guardianAccepted, isFalse);
    await timed.requestGuardian();
    t.emit(
      'data',
      data: Packet('guardianResponse', newId(), {'accepted': true}).encode(),
    );
    expect(timed.guardianAccepted, isTrue);
    await timed.disconnect();
    t.emit('invitation');
    await timed.respond(true);
    t.emit('connected');
    expect(timed.guardianAccepted, isFalse);
    timed.dispose();
    await t.stream.close();
    await l.stream.close();
  });
  testWidgets(
    'foreground check-in expiry sends an alert and purges expired notes',
    (tester) async {
      final t = FakeTransport();
      final l = FakeLocation();
      final timed = LanternController(t, l, FakeProfile());
      await timed.initialize();
      await timed.start();
      t.emit('invitation');
      await timed.respond(true);
      t.emit('connected');
      await timed.requestGuardian();
      t.emit(
        'data',
        data: Packet('guardianResponse', newId(), {'accepted': true}).encode(),
      );
      timed.notes.add(
        Note(
          newId(),
          'Expired',
          true,
          DateTime.now(),
          Delivery.sent,
          expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );
      timed.armCheckIn(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(timed.notes, isEmpty);
      expect(timed.checkInUntil, isNull);
      final packets = t.calls
          .where((call) => call.$1 == 'send')
          .map((call) => Packet.decode(call.$2!['data'] as String));
      expect(packets.any((packet) => packet?.kind == 'guardianAlert'), isTrue);
      timed.dispose();
      await t.stream.close();
      await l.stream.close();
    },
  );
  test('navigation vector uses true north and shortest dateline distance', () {
    final east = vectorBetween(const Fix(0, 0, 0), const Fix(0, 1, 0));
    expect(east.distanceMeters, closeTo(111195, 1));
    expect(east.bearingDegrees, closeTo(90, 0.001));
    final dateline = vectorBetween(
      const Fix(0, 179.9, 0),
      const Fix(0, -179.9, 0),
    );
    expect(dateline.distanceMeters, closeTo(22239, 1));
    expect(
      () => vectorBetween(const Fix(double.nan, 0, 0), const Fix(0, 0, 0)),
      throwsArgumentError,
    );
  });
}
