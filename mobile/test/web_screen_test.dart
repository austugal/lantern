import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/web_screen.dart';
import 'package:lantern/src/web_store.dart';

void main() {
  testWidgets('saved library opens without initializing a platform WebView', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: WebScreen(store: _EmptyStore())));
    await tester.pumpAndSettle();
    expect(find.text('Web & saved reading'), findsOneWidget);
    expect(
      find.text(
        'No saved pages. Browse online, then explicitly save readable page text.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'offline reader renders hostile HTML as literal text at small width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final page = SavedWebPage(
        id: 'example',
        url: 'https://example.com',
        title: 'Saved page',
        text: '<script>window.location="https://example.org"</script>',
        savedAt: DateTime.utc(2026),
      );
      await tester.pumpWidget(
        MaterialApp(home: SavedReadingScreen(page: page)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offline saved text'), findsOneWidget);
      expect(find.text(page.text), findsOneWidget);
      expect(find.byType(SelectableText), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}

class _EmptyStore extends WebReadingStore {
  @override
  Future<List<SavedWebPage>> read() async => [];
}
