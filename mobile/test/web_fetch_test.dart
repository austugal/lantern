import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/web_fetch.dart';
import 'package:lantern/src/web_store.dart';

class _Transport implements PublicTextTransport {
  _Transport(this.responses);
  final List<PublicTextResponse> responses;
  final requested = <Uri>[];
  bool closed = false;
  @override
  Future<PublicTextResponse> get(Uri uri) async {
    requested.add(uri);
    return responses.removeAt(0);
  }

  @override
  void close() {
    closed = true;
  }
}

PublicTextResponse response(String body, {String type = 'text/html'}) =>
    PublicTextResponse(
      status: 200,
      body: Stream.value(utf8.encode(body)),
      contentType: type,
    );
PublicTextResponse redirect(String address) => PublicTextResponse(
  status: 302,
  body: const Stream.empty(),
  location: address,
);

void main() {
  final address = Uri.parse('https://example.com/article');
  test('parser excludes executable content, form controls and hidden text', () {
    final result = parsePublicText(
      '<title>Report</title><h1>Public heading</h1><p>One</p><p>Two</p><script>SECRET_SCRIPT</script><style>SECRET_STYLE</style><form>SECRET_FORM<input value="SECRET_INPUT"></form><textarea>SECRET_TEXTAREA</textarea><div hidden>SECRET_HIDDEN</div><div aria-hidden="true">SECRET_ARIA</div><div style="display:none">SECRET_CSS</div>',
    );
    expect(result.$1, 'Report');
    expect(result.$2, contains('Public heading'));
    expect(result.$2, contains('One\n'));
    expect(result.$2, contains('Two'));
    expect(result.$2, isNot(contains('SECRET')));
  });
  test(
    'downloader follows bounded public redirects and closes its client',
    () async {
      final transport = _Transport([
        redirect('/public'),
        response('<title>Public</title><p>Readable</p>'),
      ]);
      final downloaded = await fetchPublicText(address, transport: transport);
      expect(downloaded.url.toString(), 'https://example.com/public');
      expect(downloaded.text, 'Readable');
      expect(transport.requested, [
        address,
        Uri.parse('https://example.com/public'),
      ]);
      expect(transport.closed, isTrue);
    },
  );
  test(
    'private or insecure redirects are blocked before the next request',
    () async {
      for (final target in [
        'https://127.0.0.1/private',
        'http://example.com',
        'file:///x',
      ]) {
        final transport = _Transport([redirect(target)]);
        await expectLater(
          fetchPublicText(address, transport: transport),
          throwsFormatException,
        );
        expect(transport.requested, hasLength(1));
        expect(transport.closed, isTrue);
      }
    },
  );
  test('redirect loops stop after three hops', () async {
    final transport = _Transport(List.generate(4, (_) => redirect('/loop')));
    await expectLater(
      fetchPublicText(address, transport: transport),
      throwsFormatException,
    );
    expect(transport.requested, hasLength(4));
    expect(transport.closed, isTrue);
  });
  test(
    'stream download limit rejects oversized chunks and cancels client',
    () async {
      final transport = _Transport([
        PublicTextResponse(
          status: 200,
          contentType: 'text/plain',
          body: Stream.fromIterable([
            List.filled(maxReadingBytes, 65),
            [65],
          ]),
        ),
      ]);
      await expectLater(
        fetchPublicText(address, transport: transport),
        throwsFormatException,
      );
      expect(transport.closed, isTrue);
    },
  );
  test(
    'binary responses rejected and text bounded to reading character limit',
    () async {
      final binary = _Transport([
        response('fake binary', type: 'application/pdf'),
      ]);
      await expectLater(
        fetchPublicText(address, transport: binary),
        throwsFormatException,
      );
      expect(binary.closed, isTrue);
      final plain = _Transport([
        response('x' * (maxReadingCharacters + 20), type: 'text/plain'),
      ]);
      final downloaded = await fetchPublicText(address, transport: plain);
      expect(downloaded.text.length, maxReadingCharacters);
      expect(plain.closed, isTrue);
    },
  );
}
