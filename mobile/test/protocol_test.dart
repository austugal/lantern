import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/protocol.dart';

void main() {
  test('valid messages round trip, including Unicode', () {
    final p = Packet('text', newId(), {'text': 'Olá Melbourne 👋'});
    expect(Packet.decode(p.encode())?.body['text'], 'Olá Melbourne 👋');
  });
  test('untrusted envelopes fail closed', () {
    for (final raw in [
      'null',
      '[]',
      '{',
      '"text"',
      '{}',
      jsonEncode({
        'v': 2,
        'kind': 'text',
        'id': newId(),
        'body': {'text': 'hi'},
      }),
    ]) {
      expect(Packet.decode(raw), isNull);
    }
    expect(Packet.decode(Packet('unknown', newId(), {}).encode()), isNull);
    expect(
      Packet.decode(Packet('text', 'bad-id', {'text': 'Hi'}).encode()),
      isNull,
    );
    expect(
      Packet.decode(Packet('text', newId(), {'text': 8}).encode()),
      isNull,
    );
    expect(
      Packet.decode(Packet('text', newId(), {'text': ' '}).encode()),
      isNull,
    );
    expect(
      Packet.decode(Packet('text', newId(), {'text': 'x' * 1001}).encode()),
      isNull,
    );
    expect(Packet.decode('x' * 8193), isNull);
  });
  test('location requires bounded finite numeric coordinates', () {
    for (final body in [
      {'lat': 91, 'lon': 0, 'accuracy': 5},
      {'lat': 0, 'lon': -181, 'accuracy': 5},
      {'lat': '0', 'lon': 0, 'accuracy': 5},
      {'lat': 0, 'lon': 0, 'accuracy': -1},
      {'lat': 0, 'lon': 0},
    ]) {
      expect(Packet.decode(Packet('location', newId(), body).encode()), isNull);
    }
    expect(
      Packet.decode(
        Packet('location', newId(), {
          'lat': -37.8,
          'lon': 144.9,
          'accuracy': 12,
        }).encode(),
      ),
      isNotNull,
    );
  });
}
