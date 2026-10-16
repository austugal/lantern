import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/offline_guide.dart';

void main() {
  test(
    'guide search is local, case-insensitive and has honest no-match results',
    () {
      expect(searchGuide(''), hasLength(guideTopics.length));
      expect(searchGuide('HOTEL staff').single.title, 'Hotel staff handover');
      expect(
        searchGuide('on-device').single.answer,
        contains('not configured'),
      );
      expect(searchGuide('unknown-zzzz'), isEmpty);
      expect(
        searchGuide('guardian').single.answer,
        contains('cancels the timer'),
      );
    },
  );
  testWidgets('offline guide searches and scrolls on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showOfflineGuide(context),
              child: const Text('Guide'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Built-in guidance, not AI.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hotel');
    await tester.pumpAndSettle();
    expect(find.text('Hotel staff handover'), findsOneWidget);
    expect(find.text('Connect two phones'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Copy handover template'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close offline guide'));
    await tester.pumpAndSettle();
    expect(find.text('Guide'), findsOneWidget);
  });
}
