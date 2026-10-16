import 'dart:convert';
import 'dart:math';

String newId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Strict, bounded wire format. Identity always comes from the native endpoint,
/// never from a sender field supplied inside a packet.
class Packet {
  const Packet(this.kind, this.id, this.body);
  final String kind;
  final String id;
  final Map<String, dynamic> body;
  static const maxBytes = 8192;
  String encode() => jsonEncode({'v': 1, 'kind': kind, 'id': id, 'body': body});
  static Packet? decode(String raw) {
    if (raw.length > maxBytes || utf8.encode(raw).length > maxBytes) {
      return null;
    }
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['v'] != 1) {
        return null;
      }
      final kind = data['kind'];
      final id = data['id'];
      final body = data['body'];
      if (id is! String ||
          !RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
          body is! Map<String, dynamic>) {
        return null;
      }
      switch (kind) {
        case 'text':
          if (body['text'] is! String ||
              (body['text'] as String).trim().isEmpty ||
              (body['text'] as String).length > 1000) {
            return null;
          }
          if (body.containsKey('ttl') &&
              (body['ttl'] is! int ||
                  ![60, 300, 900, 3600].contains(body['ttl']))) {
            return null;
          }
        case 'guardianRequest':
        case 'guardianAlert':
          if (body.isNotEmpty) {
            return null;
          }
        case 'guardianResponse':
          if (body.length != 1 || body['accepted'] is! bool) {
            return null;
          }
        case 'ack':
          if (body['id'] is! String ||
              !RegExp(r'^[a-f0-9]{32}$').hasMatch(body['id'])) {
            return null;
          }
        case 'location':
          for (final field in ['lat', 'lon', 'accuracy']) {
            if (body[field] is! num || !(body[field] as num).isFinite) {
              return null;
            }
          }
          if ((body['lat'] as num).abs() > 90 ||
              (body['lon'] as num).abs() > 180 ||
              body['accuracy'] < 0 ||
              body['accuracy'] > 100000) {
            return null;
          }
        case 'locationStop':
          break;
        default:
          return null;
      }
      return Packet(kind as String, id, body);
    } on FormatException {
      return null;
    }
  }
}
