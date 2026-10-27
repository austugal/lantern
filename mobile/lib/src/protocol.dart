import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

String newId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

const maxAttachmentBytes = 1024 * 1024;
const attachmentChunkBytes = 4096;
const attachmentMimes = {'image/jpeg', 'image/png', 'audio/mp4'};

/// Checks container signatures and image dimensions before passing bytes to a
/// media decoder. This is not a complete multimedia decoder or malware scanner.
bool validAttachment(Uint8List bytes, String mime) {
  if (bytes.isEmpty || bytes.length > maxAttachmentBytes) {
    return false;
  }
  bool dimensions(int width, int height) =>
      width > 0 &&
      height > 0 &&
      width <= 2048 &&
      height <= 2048 &&
      width * height <= 4000000;
  if (mime == 'image/png') {
    if (bytes.length < 33) {
      return false;
    }
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) {
        return false;
      }
    }
    final data = ByteData.sublistView(bytes);
    return data.getUint32(8) == 13 &&
        ascii.decode(bytes.sublist(12, 16), allowInvalid: true) == 'IHDR' &&
        dimensions(data.getUint32(16), data.getUint32(20));
  }
  if (mime == 'image/jpeg') {
    if (bytes.length < 12 ||
        bytes[0] != 255 ||
        bytes[1] != 216 ||
        bytes[bytes.length - 2] != 255 ||
        bytes.last != 217) {
      return false;
    }
    var offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset++] != 255) {
        return false;
      }
      while (offset < bytes.length && bytes[offset] == 255) {
        offset++;
      }
      if (offset + 3 > bytes.length) {
        return false;
      }
      final marker = bytes[offset++];
      if (marker == 218 || marker == 217) {
        return false;
      }
      final length = (bytes[offset] << 8) + bytes[offset + 1];
      if (length < 2 || offset + length > bytes.length) {
        return false;
      }
      if ({192, 193, 194}.contains(marker)) {
        if (length < 8) {
          return false;
        }
        return dimensions(
          (bytes[offset + 5] << 8) + bytes[offset + 6],
          (bytes[offset + 3] << 8) + bytes[offset + 4],
        );
      }
      offset += length;
    }
    return false;
  }
  if (mime == 'audio/mp4') {
    if (bytes.length < 16) {
      return false;
    }
    final data = ByteData.sublistView(bytes);
    final size = data.getUint32(0);
    return size >= 16 &&
        size <= bytes.length &&
        ascii.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp' &&
        {
          'M4A ',
          'mp42',
          'isom',
          'iso2',
        }.contains(ascii.decode(bytes.sublist(8, 12), allowInvalid: true));
  }
  return false;
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
          const textFields = {
            'text',
            'ttl',
            'responseRequested',
            'replyTo',
            'decision',
          };
          if (body.keys.any((field) => !textFields.contains(field))) {
            return null;
          }
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
          final responseRequested = body.containsKey('responseRequested');
          if (responseRequested && body['responseRequested'] != true) {
            return null;
          }
          final hasReplyTo = body.containsKey('replyTo');
          final hasDecision = body.containsKey('decision');
          if (hasReplyTo != hasDecision ||
              (responseRequested && hasReplyTo) ||
              ((responseRequested || hasReplyTo) && body.containsKey('ttl'))) {
            return null;
          }
          if (hasReplyTo) {
            if (body['replyTo'] is! String ||
                !RegExp(r'^[a-f0-9]{32}$').hasMatch(body['replyTo']) ||
                body['replyTo'] == id ||
                !{'accepted', 'declined'}.contains(body['decision'])) {
              return null;
            }
            final expectedText = body['decision'] == 'accepted'
                ? 'Accepted'
                : 'Declined';
            if (body['text'] != expectedText) {
              return null;
            }
          }
        case 'attachmentStart':
          if (body['mime'] is! String ||
              !attachmentMimes.contains(body['mime']) ||
              body['size'] is! int ||
              body['size'] < 1 ||
              body['size'] > maxAttachmentBytes ||
              body['chunks'] is! int ||
              body['chunks'] !=
                  ((body['size'] as int) + attachmentChunkBytes - 1) ~/
                      attachmentChunkBytes) {
            return null;
          }
          if (body.containsKey('ttl') &&
              (body['ttl'] is! int ||
                  ![60, 300, 900, 3600].contains(body['ttl']))) {
            return null;
          }
        case 'attachmentChunk':
          if (body['transfer'] is! String ||
              !RegExp(r'^[a-f0-9]{32}$').hasMatch(body['transfer']) ||
              body['index'] is! int ||
              body['index'] < 0 ||
              body['index'] >= 256 ||
              body['data'] is! String ||
              (body['data'] as String).length > 5464) {
            return null;
          }
          final chunk = base64Decode(body['data'] as String);
          if (chunk.isEmpty || chunk.length > attachmentChunkBytes) {
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
