import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lantern/src/web_screen.dart';
import 'package:lantern/src/web_store.dart';
import 'package:lantern/src/web_fetch.dart';
import 'dart:convert';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native browser disables scripts and public text opens offline', (
    tester,
  ) async {
    final web = await createReadingWebView();
    final loaded = Completer<void>();
    await web.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (!loaded.isCompleted) {
            loaded.complete();
          }
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WebViewWidget(controller: web)),
      ),
    );
    // Internal deterministic fixture only. No URL request and no production
    // navigation exception: loadHtmlString is used solely by this test.
    const fixture = '''<!doctype html>
<html><head><title>Lantern offline capture fixture</title></head>
<body>
<h1 id="sentinel">ORIGINAL SENTINEL</h1>
<p>Readable fixture text for offline use.</p>
<input type="password" value="INPUT_SECRET_MUST_NOT_BE_CAPTURED">
<script>
 document.getElementById('sentinel').textContent = 'SCRIPT EXECUTED';
 document.title = 'SCRIPT EXECUTED';
</script>
</body></html>''';
    await web.loadHtmlString(fixture);
    await loaded.future.timeout(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await web.getTitle(), 'Lantern offline capture fixture');
    final transport = _FixtureTransport(fixture);
    final downloaded = await fetchPublicText(
      Uri.parse('https://example.com/fixture'),
      transport: transport,
    );
    expect(transport.closed, isTrue);
    expect(downloaded.title, 'Lantern offline capture fixture');
    final text = downloaded.text;
    expect(text, contains('ORIGINAL SENTINEL'));
    expect(text, contains('Readable fixture text for offline use.'));
    expect(text, isNot(contains('SCRIPT EXECUTED')));
    expect(text, isNot(contains('INPUT_SECRET_MUST_NOT_BE_CAPTURED')));

    final directory = await Directory.systemTemp.createTemp(
      'lantern-browser-fixture-',
    );
    final store = WebReadingStore(directory: () async => directory);
    try {
      final page = SavedWebPage(
        id: 'fixture',
        url: 'https://example.com/fixture',
        title: downloaded.title,
        text: text,
        savedAt: DateTime.now(),
      );
      await store.save(page);
      final saved = (await store.read()).single;
      expect(saved.text, text);
      await web.loadHtmlString('<!doctype html><html><body></body></html>');
      await tester.pumpWidget(
        MaterialApp(home: SavedReadingScreen(page: saved)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offline saved text'), findsOneWidget);
      expect(find.text(text), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await directory.delete(recursive: true);
    }
  });
}

class _FixtureTransport implements PublicTextTransport {
  _FixtureTransport(this.html);
  final String html;
  bool closed = false;
  @override
  Future<PublicTextResponse> get(Uri uri) async =>
      PublicTextResponse(status: 200, body: Stream.value(utf8.encode(html)));
  @override
  void close() {
    closed = true;
  }
}
