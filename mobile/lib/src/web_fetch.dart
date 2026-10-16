import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'web_store.dart';

class PublicText {
  const PublicText(this.url, this.title, this.text);
  final Uri url;
  final String title, text;
}

class PublicTextResponse {
  const PublicTextResponse({
    required this.status,
    required this.body,
    this.location,
    this.contentType = 'text/html',
    this.charset = 'utf-8',
  });
  final int status;
  final Stream<List<int>> body;
  final String? location;
  final String contentType, charset;
}

abstract interface class PublicTextTransport {
  Future<PublicTextResponse> get(Uri uri);
  void close();
}

/// Separate fresh HTTP client: no browser cookies or authentication headers.
/// The requested URL may itself contain sensitive query parameters.
class HttpPublicTextTransport implements PublicTextTransport {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..userAgent = 'LanternOfflineReader/0.3';

  @override
  Future<PublicTextResponse> get(Uri uri) async {
    final request = await _client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.acceptHeader,
      'text/html,application/xhtml+xml,text/plain',
    );
    final response = await request.close();
    return PublicTextResponse(
      status: response.statusCode,
      body: response,
      location: response.headers.value(HttpHeaders.locationHeader),
      contentType: response.headers.contentType?.mimeType ?? '',
      charset: response.headers.contentType?.charset ?? 'utf-8',
    );
  }

  @override
  void close() => _client.close(force: true);
}

Future<PublicText> fetchPublicText(
  Uri address, {
  PublicTextTransport? transport,
}) async {
  final source = transport ?? HttpPublicTextTransport();
  try {
    return await _fetch(address, source).timeout(const Duration(seconds: 20));
  } finally {
    source.close();
  }
}

Future<PublicText> _fetch(Uri address, PublicTextTransport source) async {
  var uri = publicWebUri(address.toString());
  if (uri == null) {
    throw const FormatException('Use a public HTTPS page address.');
  }
  for (var redirects = 0; redirects <= 3; redirects++) {
    final response = await source.get(uri);
    if ([301, 302, 303, 307, 308].contains(response.status)) {
      await response.body.listen((_) {}).cancel();
      final target = response.location;
      if (target == null || redirects == 3) {
        throw const FormatException('Too many or invalid redirects.');
      }
      uri = publicWebUri(uri.resolve(target).toString());
      if (uri == null) {
        throw const FormatException(
          'Redirect to a local or unsupported address was blocked.',
        );
      }
      continue;
    }
    if (response.status != 200) {
      throw HttpException('Public page returned HTTP ${response.status}.');
    }
    if (![
      'text/html',
      'application/xhtml+xml',
      'text/plain',
    ].contains(response.contentType.toLowerCase())) {
      throw const FormatException(
        'This address does not return an HTML or plain-text page.',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.body) {
      if (bytes.length + chunk.length > maxReadingBytes) {
        throw const FormatException(
          'Public page exceeds the 1 MiB download limit.',
        );
      }
      bytes.addAll(chunk);
    }
    final encoding = Encoding.getByName(response.charset.toLowerCase());
    if (encoding == null) {
      throw const FormatException(
        'This page uses an unsupported text encoding.',
      );
    }
    final document = encoding.decode(bytes);
    final parsed = parsePublicText(
      document,
      plainText: response.contentType.toLowerCase() == 'text/plain',
    );
    if (parsed.$2.isEmpty) {
      throw const FormatException(
        'No readable public text was found. The website may require login or scripts.',
      );
    }
    return PublicText(uri, parsed.$1.isEmpty ? uri.host : parsed.$1, parsed.$2);
  }
  throw const FormatException('Too many redirects.');
}

/// Parses downloaded HTML as inert data. Never evaluates scripts or uses WebView.
(String, String) parsePublicText(String source, {bool plainText = false}) {
  if (utf8.encode(source).length > maxReadingBytes) {
    throw const FormatException('Text input exceeds 1 MiB.');
  }
  if (plainText) {
    return ('', _bounded(source.trim(), maxReadingCharacters));
  }
  final document = html.parse(source);
  final title = _bounded(
    document.querySelector('title')?.text.trim() ?? '',
    300,
  );
  final body = document.body;
  if (body == null) {
    return (title, '');
  }
  const excluded = {
    'script',
    'style',
    'form',
    'input',
    'textarea',
    'select',
    'option',
    'button',
    'template',
    'iframe',
    'object',
    'embed',
    'svg',
    'math',
    'canvas',
    'video',
    'audio',
  };
  const blocks = {
    'p',
    'div',
    'br',
    'li',
    'ul',
    'ol',
    'section',
    'article',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'tr',
    'td',
    'blockquote',
    'pre',
  };
  final stack = <(dom.Node, bool)>[(body, false)];
  final output = StringBuffer();
  var visited = 0;
  while (stack.isNotEmpty && output.length < maxReadingCharacters) {
    final (node, exiting) = stack.removeLast();
    if (++visited > 50000) {
      throw const FormatException(
        'Page structure is too complex for offline reading.',
      );
    }
    if (node is dom.Text) {
      output.write(node.data);
      continue;
    }
    if (node is! dom.Element) {
      continue;
    }
    if (excluded.contains(node.localName) ||
        node.attributes.containsKey('hidden') ||
        node.attributes['aria-hidden'] == 'true' ||
        RegExp(
          r'display\s*:\s*none|visibility\s*:\s*hidden',
          caseSensitive: false,
        ).hasMatch(node.attributes['style'] ?? '')) {
      continue;
    }
    if (blocks.contains(node.localName)) {
      output.write('\n');
    }
    if (exiting) {
      continue;
    }
    stack.add((node, true));
    for (final child in node.nodes.reversed) {
      stack.add((child, false));
    }
  }
  final text = output
      .toString()
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
      .trim();
  return (title, _bounded(text, maxReadingCharacters));
}

String _bounded(String text, int maximum) =>
    text.length <= maximum ? text : text.substring(0, maximum);
