// Standalone CLI intentionally imports source directly and prints its result.
// ignore_for_file: avoid_relative_lib_imports, avoid_print
// Standalone offline checks: dart tool/protocol_check.dart
import 'dart:convert';
import 'dart:math';
import '../lib/src/protocol.dart';

void main() {
  var checks = 0;
  void check(bool condition, String reason) {
    checks++;
    if (!condition) throw StateError(reason);
  }

  final text = Packet('text', newId(), {'text': 'Olá Melbourne 👋'});
  check(
    Packet.decode(text.encode())?.body['text'] == text.body['text'],
    'Unicode round trip',
  );
  for (final raw in ['null', '[]', '{}', '"text"', '{', 'x' * 8193]) {
    check(Packet.decode(raw) == null, 'Malformed or oversized envelope');
  }
  for (final body in [
    {'lat': 91, 'lon': 0, 'accuracy': 1},
    {'lat': 0, 'lon': -181, 'accuracy': 1},
    {'lat': '0', 'lon': 0, 'accuracy': 1},
    {'lat': 0, 'lon': 0, 'accuracy': -1},
    {'lat': 0, 'lon': 0},
  ]) {
    check(
      Packet.decode(Packet('location', newId(), body).encode()) == null,
      'Invalid coordinates',
    );
  }
  check(
    Packet.decode(
          Packet('location', newId(), {
            'lat': -37.8,
            'lon': 144.9,
            'accuracy': 5,
          }).encode(),
        ) !=
        null,
    'Valid coordinates',
  );
  check(
    Packet.decode(Packet('text', newId(), {'text': 'x' * 1001}).encode()) ==
        null,
    'Message length bound',
  );
  check(
    Packet.decode(Packet('text', newId(), {'text': ' '}).encode()) == null,
    'Empty message',
  );
  check(
    Packet.decode(Packet('ack', newId(), {'id': text.id}).encode()) != null,
    'Acknowledgement',
  );
  check(
    Packet.decode(Packet('locationStop', newId(), {}).encode()) != null,
    'Location revocation',
  );
  check(
    Packet.decode(Packet('unexpected', newId(), {}).encode()) == null,
    'Unknown kind',
  );
  check(
    Packet.decode(
          jsonEncode({
            'v': 2,
            'kind': 'text',
            'id': newId(),
            'body': {'text': 'hi'},
          }),
        ) ==
        null,
    'Unknown version',
  );
  final random = Random(42);
  for (var i = 0; i < 10000; i++) {
    final raw = String.fromCharCodes(
      List.generate(random.nextInt(128), (_) => random.nextInt(128)),
    );
    check(
      Packet.decode(raw) == null,
      'Fuzz input $i must not crash or decode as a packet',
    );
  }
  print(
    '$checks protocol checks passed. No Flutter, native transport or device tests were run.',
  );
}
