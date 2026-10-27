import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/controller.dart';
import 'package:lantern/src/protocol.dart';

import 'fakes.dart';

class _HeldTransport extends FakeTransport {
  bool holdText = false;
  final pending = <Completer<void>>[];

  @override
  Future<void> call(String method, [Map<String, dynamic>? args]) {
    if (method == 'send' &&
        holdText &&
        Packet.decode(args!['data'] as String)?.kind == 'text') {
      calls.add((method, args));
      final completion = Completer<void>();
      pending.add(completion);
      return completion.future;
    }
    return super.call(method, args);
  }
}

class _Session {
  _Session([FakeTransport? transport])
    : transport = transport ?? FakeTransport();

  final FakeTransport transport;
  final location = FakeLocation();
  late final controller = LanternController(transport, location, FakeProfile());

  List<Packet> get packets => transport.calls
      .where((call) => call.$1 == 'send')
      .map((call) => Packet.decode(call.$2!['data'] as String))
      .whereType<Packet>()
      .toList();
  List<Packet> get texts =>
      packets.where((packet) => packet.kind == 'text').toList();
  List<Packet> get receipts =>
      packets.where((packet) => packet.kind == 'ack').toList();

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

  void receive(Packet packet) => transport.emit('data', data: packet.encode());
  void acknowledge(String id) => receive(Packet('ack', newId(), {'id': id}));

  Future<void> close() async {
    controller.dispose();
    await transport.stream.close();
    await location.stream.close();
  }
}

void _sessionTest(
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
  test('work-request wire metadata is strict and cannot disappear', () {
    final requestId = newId();
    expect(
      Packet.decode(
        Packet('text', requestId, {
          'text': 'Please inspect the corridor',
          'responseRequested': true,
        }).encode(),
      ),
      isNotNull,
    );
    expect(
      Packet.decode(
        Packet('text', newId(), {
          'text': 'Accepted',
          'replyTo': requestId,
          'decision': 'accepted',
        }).encode(),
      ),
      isNotNull,
    );

    final invalidBodies = <Map<String, dynamic>>[
      {'text': 'Request', 'responseRequested': false},
      {'text': 'Request', 'responseRequested': 'yes'},
      {'text': 'Request', 'responseRequested': true, 'ttl': 60},
      {
        'text': 'Request',
        'responseRequested': true,
        'replyTo': requestId,
        'decision': 'accepted',
      },
      {'text': 'Accepted', 'replyTo': requestId},
      {'text': 'Accepted', 'decision': 'accepted'},
      {'text': 'Accepted', 'replyTo': 'bad', 'decision': 'accepted'},
      {'text': 'Accepted', 'replyTo': requestId, 'decision': 'maybe'},
      {
        'text': 'Accepted',
        'replyTo': requestId,
        'decision': 'accepted',
        'ttl': 60,
      },
      {'text': 'Request', 'responseRequested': true, 'unexpected': true},
    ];
    for (final body in invalidBodies) {
      expect(Packet.decode(Packet('text', newId(), body).encode()), isNull);
    }
    expect(
      Packet.decode(
        Packet('text', requestId, {
          'text': 'Accepted',
          'replyTo': requestId,
          'decision': 'accepted',
        }).encode(),
      ),
      isNull,
    );
  });

  _sessionTest('request sender sees only a valid first human decision', (
    tester,
    s,
  ) async {
    expect(
      await s.controller.send(
        'Housekeeping request: towels to floor 2',
        responseRequested: true,
      ),
      isTrue,
    );
    final request = s.controller.notes.single;
    expect(request.responseRequested, isTrue);
    expect(request.workDecision, isNull);
    expect(s.texts.single.body, {
      'text': request.text,
      'responseRequested': true,
    });

    s.acknowledge(request.id);
    final receiptsBefore = s.receipts.length;
    final responseId = newId();
    final accepted = Packet('text', responseId, {
      'text': 'Accepted',
      'replyTo': request.id,
      'decision': 'accepted',
    });
    s.receive(accepted);
    expect(request.workDecision, WorkDecision.accepted);
    expect(s.controller.notes, hasLength(2));
    expect(s.controller.notes.last.replyTo, request.id);
    expect(s.receipts, hasLength(receiptsBefore + 1));

    // A repeated packet is acknowledged again, but never displayed twice.
    s.receive(accepted);
    expect(s.controller.notes, hasLength(2));
    expect(s.receipts, hasLength(receiptsBefore + 2));

    // Reusing an accepted ID with a different valid payload is not a retry.
    s.receive(
      Packet('text', responseId, {
        'text': 'Accepted',
        'replyTo': newId(),
        'decision': 'accepted',
      }),
    );
    expect(s.controller.notes, hasLength(2));
    expect(s.receipts, hasLength(receiptsBefore + 2));

    // A later conflicting decision is invalid and gets no false receipt.
    s.receive(
      Packet('text', newId(), {
        'text': 'Declined',
        'replyTo': request.id,
        'decision': 'declined',
      }),
    );
    expect(request.workDecision, WorkDecision.accepted);
    expect(s.controller.notes, hasLength(2));
    expect(s.receipts, hasLength(receiptsBefore + 2));
    await tester.pump();
  });

  _sessionTest('receiver responds once through normal text delivery', (
    tester,
    s,
  ) async {
    final requestId = newId();
    s.receive(
      Packet('text', requestId, {
        'text': 'Please inspect the service corridor',
        'responseRequested': true,
      }),
    );
    final request = s.controller.notes.single;
    expect(s.controller.canRespondToRequest(request), isTrue);

    // Response delivery is non-disappearing even if the local composer is.
    s.controller.setMessageLifetime(60);
    final first = s.controller.respondToRequest(request, WorkDecision.accepted);
    final second = s.controller.respondToRequest(
      request,
      WorkDecision.declined,
    );
    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(request.workDecision, WorkDecision.accepted);
    expect(s.controller.notes, hasLength(2));
    final response = s.controller.notes.last;
    expect(response.text, 'Accepted');
    expect(response.replyTo, request.id);
    expect(response.workDecision, WorkDecision.accepted);
    expect(response.expiresAt, isNull);
    expect(s.controller.canRespondToRequest(request), isFalse);

    final responsePacket = s.texts.singleWhere(
      (packet) => packet.body['replyTo'] == request.id,
    );
    expect(responsePacket.body, {
      'text': 'Accepted',
      'replyTo': request.id,
      'decision': 'accepted',
    });
    s.acknowledge(response.id);
    expect(response.delivery, Delivery.delivered);
    await tester.pump();
  });

  _sessionTest('unknown and ordinary-message responses get no receipt', (
    tester,
    s,
  ) async {
    final receiptsBefore = s.receipts.length;
    s.receive(
      Packet('text', newId(), {
        'text': 'Accepted',
        'replyTo': newId(),
        'decision': 'accepted',
      }),
    );
    expect(s.controller.notes, isEmpty);
    expect(s.receipts, hasLength(receiptsBefore));

    expect(await s.controller.send('Ordinary text'), isTrue);
    final ordinary = s.controller.notes.single;
    s.receive(
      Packet('text', newId(), {
        'text': 'Accepted',
        'replyTo': ordinary.id,
        'decision': 'accepted',
      }),
    );
    expect(ordinary.workDecision, isNull);
    expect(s.controller.notes, hasLength(1));
    expect(s.receipts, hasLength(receiptsBefore));
    await tester.pump();
  });

  _sessionTest('request and response retry preserve identity and metadata', (
    tester,
    s,
  ) async {
    s.transport.failMethod = 'send';
    expect(
      await s.controller.send('Confirm the handover', responseRequested: true),
      isFalse,
    );
    final outgoingRequest = s.controller.notes.single;
    expect(await s.controller.retry(outgoingRequest), isFalse);
    final requestPackets = s.texts.where(
      (packet) => packet.id == outgoingRequest.id,
    );
    expect(requestPackets, hasLength(2));
    expect(
      requestPackets.every(
        (packet) => packet.body['responseRequested'] == true,
      ),
      isTrue,
    );

    s.transport.failMethod = null;
    await s.controller.disconnect();
    await s.connect();
    final incomingId = newId();
    s.receive(
      Packet('text', incomingId, {
        'text': 'Can you take this task?',
        'responseRequested': true,
      }),
    );
    final incoming = s.controller.notes.single;
    s.transport.failMethod = 'send';
    expect(
      await s.controller.respondToRequest(incoming, WorkDecision.declined),
      isFalse,
    );
    final response = s.controller.notes.last;
    expect(await s.controller.retry(response), isFalse);
    final responsePackets = s.texts.where((packet) => packet.id == response.id);
    expect(responsePackets, hasLength(2));
    expect(
      responsePackets.every(
        (packet) =>
            packet.body['replyTo'] == incomingId &&
            packet.body['decision'] == 'declined',
      ),
      isTrue,
    );
    await tester.pump();
  });

  _sessionTest('disappearing requests are refused before admission', (
    tester,
    s,
  ) async {
    s.controller.setMessageLifetime(60);
    expect(
      await s.controller.send('Temporary task', responseRequested: true),
      isFalse,
    );
    expect(s.controller.notes, isEmpty);
    expect(s.texts, isEmpty);
    expect(s.controller.error, contains('message expiry'));
    await tester.pump();
  });

  _sessionTest('response target does not survive reconnection', (
    tester,
    s,
  ) async {
    expect(
      await s.controller.send(
        'Current-session request',
        responseRequested: true,
      ),
      isTrue,
    );
    final oldId = s.controller.notes.single.id;
    await s.controller.disconnect();
    await s.connect();
    final receiptsBefore = s.receipts.length;
    s.receive(
      Packet('text', newId(), {
        'text': 'Accepted',
        'replyTo': oldId,
        'decision': 'accepted',
      }),
    );
    expect(s.controller.notes, isEmpty);
    expect(s.receipts, hasLength(receiptsBefore));
    await tester.pump();
  });

  _sessionTest('work requests use the existing eight-send bound', (
    tester,
    s,
  ) async {
    for (var i = 0; i < LanternController.maxPendingTextSends; i++) {
      expect(
        await s.controller.send('Request $i', responseRequested: true),
        isTrue,
      );
    }
    expect(
      await s.controller.send('Request overflow', responseRequested: true),
      isFalse,
    );
    expect(
      s.controller.notes,
      hasLength(LanternController.maxPendingTextSends),
    );
    expect(s.texts, hasLength(LanternController.maxPendingTextSends));
    await tester.pump();
  });

  _sessionTest('pending-send bound prevents an untracked response', (
    tester,
    s,
  ) async {
    for (var i = 0; i < LanternController.maxPendingTextSends; i++) {
      expect(await s.controller.send('Pending $i'), isTrue);
    }
    final incomingId = newId();
    s.receive(
      Packet('text', incomingId, {
        'text': 'Can you accept this task?',
        'responseRequested': true,
      }),
    );
    final incoming = s.controller.notes.last;
    expect(
      await s.controller.respondToRequest(incoming, WorkDecision.accepted),
      isFalse,
    );
    expect(incoming.workDecision, isNull);
    expect(
      s.controller.notes.where((note) => note.replyTo == incomingId),
      isEmpty,
    );
    await tester.pump();
  });

  testWidgets('disconnect makes a late response callback inert', (
    tester,
  ) async {
    final transport = _HeldTransport()..holdText = true;
    final session = _Session(transport);
    try {
      await session.open();
      final requestId = newId();
      session.receive(
        Packet('text', requestId, {
          'text': 'Please confirm this task',
          'responseRequested': true,
        }),
      );
      final incoming = session.controller.notes.single;
      final submission = session.controller.respondToRequest(
        incoming,
        WorkDecision.accepted,
      );
      final response = session.controller.notes.last;
      expect(transport.pending, hasLength(1));

      await session.controller.disconnect();
      await session.connect();
      expect(await submission, isFalse);
      session.controller.clearError();
      transport.pending.single.completeError(StateError('late response error'));
      await tester.pump();

      expect(session.controller.notes, isEmpty);
      expect(session.controller.error, isEmpty);
      expect(response.delivery, Delivery.sending);
    } finally {
      await session.close();
    }
  });
}
