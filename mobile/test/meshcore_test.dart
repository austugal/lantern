// Copyright © 2026 Tiago Fitas. All rights reserved. See LICENSE.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/meshcore.dart';
import 'package:lantern/src/meshcore_screen.dart';

class FakeRadio implements MeshRadioLink {
  final found = StreamController<MeshRadio>.broadcast(sync: true);
  final replies = StreamController<List<int>>.broadcast(sync: true);
  final writes = <List<int>>[];
  final inbox = <List<int>>[];
  int scans = 0, opens = 0, closes = 0;
  int channels = 8, version = 3;
  bool suppressSend = false, rejectSend = false;
  Completer<void>? opening;
  @override
  Stream<List<int>> get frames => replies.stream;
  @override
  Stream<MeshRadio> scan() {
    scans++;
    return found.stream;
  }

  @override
  Future<void> open(String id) async {
    opens++;
    await opening?.future;
  }

  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<void> write(List<int> frame) async {
    writes.add(List.of(frame));
    final reply = switch (frame[0]) {
      1 => [...List<int>.filled(58, 0)..[0] = 5, ...utf8.encode('My radio')],
      0x16 =>
        List<int>.filled(80, 0)
          ..[0] = 0x0d
          ..[1] = version
          ..[3] = channels,
      0x1f => [
        0x12,
        frame[1],
        ...utf8.encode('Test').followedBy(List<int>.filled(28, 0)),
        ...List<int>.filled(16, 0xaa),
      ],
      3 => suppressSend ? <int>[] : [rejectSend ? 1 : 0],
      0x0a => inbox.isEmpty ? [10] : inbox.removeAt(0),
      _ => throw StateError('Unexpected command'),
    };
    if (reply.isNotEmpty) replies.add(reply);
  }
}

List<int> radioMessage(
  String text, {
  int channel = 0,
  bool v3 = true,
  int seconds = 123,
}) {
  final time = ByteData(4)..setUint32(0, seconds, Endian.little);
  return [
    if (v3) ...[0x11, 0xfc, 0, 0] else 8,
    channel,
    0xff,
    0,
    ...time.buffer.asUint8List(),
    ...utf8.encode(text),
  ];
}

Future<void> linkUp(MeshController c, FakeRadio link) async {
  await c.scan();
  link.found.add(const MeshRadio('radio-1', 'My radio'));
  await c.connect(c.radios.values.single);
  expect(c.connected, isTrue, reason: c.error);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'command vector matches documented channel frame and UTF-8 byte cap',
    () {
      expect(MeshCodec.channelText(1, 'Hello', 1234567890), [
        3,
        0,
        1,
        0xd2,
        2,
        0x96,
        0x49,
        72,
        101,
        108,
        108,
        111,
      ]);
      expect(MeshCodec.channelText(0, 'é' * 50, 0).length, 107);
      for (final text in ['é' * 51, ' ', 'x\u0000y']) {
        expect(() => MeshCodec.channelText(0, text, 0), throwsFormatException);
      }
      expect(() => MeshCodec.channelText(40, 'x', 0), throwsFormatException);
      expect(() => MeshCodec.channelText(0, 'x', -1), throwsFormatException);
      expect(
        () => MeshCodec.channelText(0, 'x', 0x100000000),
        throwsFormatException,
      );
    },
  );
  test('old and v3 incoming packets preserve slot and timestamp', () {
    for (final v3 in [false, true]) {
      final message = MeshCodec.channelMessage(
        radioMessage('Alice: hello', channel: 3, v3: v3),
      )!;
      expect(message.channel, 3);
      expect(message.seconds, 123);
      expect(message.text, 'Alice: hello');
      expect(message.outgoing, isFalse);
    }
  });
  test(
    'malformed, non-UTF8 and unsupported frames never become channel text',
    () {
      expect(MeshCodec.channelMessage([7, 1, 2]), isNull);
      for (final frame in [
        [8],
        [0x11, 1],
        [...radioMessage('x')..[6] = 2],
        [...radioMessage(''), 0xff],
        radioMessage('null\u0000'),
        radioMessage('x', channel: 40),
      ]) {
        expect(() => MeshCodec.channelMessage(frame), throwsFormatException);
      }
    },
  );
  test(
    'opening screen/controller starts no radio and handshake is sequential',
    () async {
      final link = FakeRadio();
      final c = MeshController(link);
      expect(link.scans + link.opens, 0);
      await linkUp(c, link);
      expect(link.writes.map((x) => x[0]), [1, 0x16, 0x1f]);
      expect(link.writes[1], [0x16, 3]);
      expect(c.radioName, 'My radio');
      expect(c.channelName, 'Test');
      expect(c.maxChannels, 8);
      expect(c.canSend, isTrue);
      await c.disconnect();
      c.dispose();
    },
  );
  test(
    'negotiated channel bound is enforced and secrets are never displayed',
    () async {
      final link = FakeRadio()..channels = 2;
      final c = MeshController(link);
      await linkUp(c, link);
      await c.selectChannel(1);
      expect(c.channel, 1);
      final count = link.writes.length;
      await c.selectChannel(2);
      expect(link.writes.length, count);
      expect(c.channelName, 'Test');
      expect(c.status, isNot(contains('aaaa')));
      await c.disconnect();
      c.dispose();
    },
  );
  test('unsupported firmware fails closed', () async {
    final link = FakeRadio()..version = 2;
    final c = MeshController(link);
    await c.scan();
    link.found.add(const MeshRadio('r', 'r'));
    await c.connect(c.radios.values.single);
    expect(c.connected, isFalse);
    expect(c.error, isNotNull);
    expect(link.writes.map((x) => x[0]), [1, 0x16]);
    c.dispose();
  });
  test(
    'radio OK is acceptance only, no delivery claim and no automatic reads',
    () async {
      final link = FakeRadio();
      final c = MeshController(link);
      await linkUp(c, link);
      link.replies.add([0x83]);
      await Future<void>.delayed(Duration.zero);
      expect(link.writes.length, 3);
      expect(await c.send('Hello'), isTrue);
      expect(c.messages.single.outgoing, isTrue);
      expect(c.status, contains('Recipient delivery is unconfirmed'));
      expect(link.writes.where((x) => x[0] == 3).length, 1);
      await c.disconnect();
      c.dispose();
    },
  );
  test(
    'invalid text never writes, radio rejection closes without retry',
    () async {
      final link = FakeRadio()..rejectSend = true;
      final c = MeshController(link);
      await linkUp(c, link);
      expect(await c.send('x' * 101), isFalse);
      expect(link.writes.length, 3);
      expect(await c.send('Hello'), isFalse);
      expect(c.connected, isFalse);
      expect(c.error, contains('Send unconfirmed'));
      expect(link.writes.where((x) => x[0] == 3).length, 1);
      c.dispose();
    },
  );
  test(
    'timeout ends uncorrelated session; late OK cannot confirm a new send',
    () async {
      final link = FakeRadio()..suppressSend = true;
      final c = MeshController(
        link,
        deadline: const Duration(milliseconds: 20),
      );
      await linkUp(c, link);
      expect(await c.send('Hello'), isFalse);
      expect(c.connected, isFalse);
      link.replies.add([0]);
      expect(c.messages, isEmpty);
      expect(await c.send('Hello'), isFalse);
      expect(link.writes.where((x) => x[0] == 3).length, 1);
      c.dispose();
    },
  );
  test('disconnect cancels a pending send and invalidates callbacks', () async {
    final link = FakeRadio()..suppressSend = true;
    final c = MeshController(link);
    await linkUp(c, link);
    final sending = c.send('One');
    await Future<void>.delayed(Duration.zero);
    await c.disconnect();
    expect(await sending, isFalse);
    link.replies.add([0]);
    expect(c.messages, isEmpty);
    expect(c.connected, isFalse);
    c.dispose();
  });
  test(
    'disconnect during connect cannot revive radio or issue commands',
    () async {
      final link = FakeRadio()..opening = Completer<void>();
      final c = MeshController(link);
      await c.scan();
      link.found.add(const MeshRadio('r', 'r'));
      final connecting = c.connect(c.radios.values.single);
      await Future<void>.delayed(Duration.zero);
      await c.disconnect();
      link.opening!.complete();
      await connecting;
      expect(c.connected, isFalse);
      expect(link.writes, isEmpty);
      c.dispose();
    },
  );
  test(
    'inbox decoding, dedupe, unsupported counter and bounded drain',
    () async {
      final link = FakeRadio();
      final c = MeshController(link);
      await linkUp(c, link);
      link.inbox.addAll([
        radioMessage('Hi'),
        radioMessage('Hi'),
        [7, 0],
        ...List.generate(22, (i) => radioMessage('Item $i', seconds: i)),
      ]);
      await c.receive();
      expect(link.inbox.length, 5);
      expect(c.messages.length, 18);
      expect(c.skippedMessages, 1);
      expect(c.status, contains('20 queued items'));
      await c.receive();
      expect(c.messages.length, 23);
      await c.disconnect();
      expect(c.messages, isEmpty);
      expect(c.radios, isEmpty);
      c.dispose();
    },
  );
  test(
    'malformed expected reply closes session without displaying text',
    () async {
      final link = FakeRadio();
      final c = MeshController(link);
      await linkUp(c, link);
      link.inbox.add([0x11, 0]);
      await c.receive();
      expect(c.connected, isFalse);
      expect(c.messages, isEmpty);
      expect(c.error, isNotNull);
      c.dispose();
    },
  );
  test('discovered device list is bounded', () async {
    final link = FakeRadio();
    final c = MeshController(link);
    await c.scan();
    for (var i = 0; i < 60; i++) {
      link.found.add(MeshRadio('$i', 'Radio $i'));
    }
    expect(c.radios.length, 32);
    await c.disconnect();
    c.dispose();
  });
  testWidgets(
    'screen opens offline with no plugin access, works at enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final link = FakeRadio();
      final c = MeshController(link);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: MeshCoreScreen(controller: c),
        ),
      );
      expect(link.scans + link.opens, 0);
      expect(find.text('MeshCore radio'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Scan for MeshCore radio'),
        160,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'connected screen requires confirmation before consuming shared inbox',
    (tester) async {
      final link = FakeRadio();
      final c = MeshController(link);
      await linkUp(c, link);
      await tester.pumpWidget(MaterialApp(home: MeshCoreScreen(controller: c)));
      await tester.scrollUntilVisible(find.text('Receive radio inbox'), 200);
      await tester.tap(find.text('Receive radio inbox'));
      await tester.pumpAndSettle();
      expect(find.text('Read the shared radio inbox?'), findsOneWidget);
      expect(link.writes.where((x) => x[0] == 0x0a), isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(link.writes.where((x) => x[0] == 0x0a), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
