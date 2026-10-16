import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/web_store.dart';

SavedWebPage page(String id, {String text = 'Readable text'}) => SavedWebPage(
  id: id,
  url: 'https://example.com/article',
  title: 'An article',
  text: text,
  savedAt: DateTime.utc(2026, 10, 16),
);

void main() {
  test(
    'public HTTPS navigation rejects unsafe schemes and local-address forms',
    () {
      expect(
        publicWebUri('example.com/news')?.toString(),
        'https://example.com/news',
      );
      expect(
        publicWebUri('https://EXAMPLE.com.:443/path')?.host,
        'example.com',
      );
      for (final address in [
        'http://example.com',
        'javascript:alert(1)',
        'data:text/html,x',
        'file:///etc/passwd',
        'mailto:a@example.com',
        'https://user:secret@example.com',
        'https://example.com:8443',
        'https://127.0.0.1',
        'https://10.0.0.1',
        'https://192.168.1.1',
        'https://172.16.0.1',
        'https://169.254.169.254',
        'https://[::1]',
        'https://[fc00::1]',
        'https://8.8.8.8',
        'https://localhost',
        'https://x.localhost',
        'https://hotel.local',
        'https://router.lan',
        'https://2130706433',
        'https://0x7f000001',
        'https://0177.0.0.1',
        'https://example.com\\@localhost',
        'https://exa mple.com',
        'https://example..com',
        'https://-invalid.com',
        'https://example.com\nfile:///x',
      ]) {
        expect(publicWebUri(address), isNull, reason: address);
      }
    },
  );

  late Directory directory;
  late WebReadingStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lantern-web-test-');
    store = WebReadingStore(directory: () async => directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'saved text roundtrips atomically and delete preserves other pages',
    () async {
      await store.save(page('first', text: '<script>not executable</script>'));
      await store.save(page('second'));
      final saved = await store.read();
      expect(saved.map((p) => p.id), ['second', 'first']);
      expect(saved.last.text, '<script>not executable</script>');
      expect(
        directory.listSync().any((f) => f.path.endsWith('.pending')),
        isFalse,
      );
      await store.delete('first');
      expect((await store.read()).single.id, 'second');
      await store.clear();
      expect(await store.read(), isEmpty);
    },
  );

  test(
    'concurrent writes serialize and collection has a strict page limit',
    () async {
      await Future.wait(
        List.generate(maxReadingPages, (i) => store.save(page('p$i'))),
      );
      expect(await store.read(), hasLength(maxReadingPages));
      await expectLater(store.save(page('overflow')), throwsStateError);
      expect(await store.read(), hasLength(maxReadingPages));
    },
  );

  test(
    'rejects oversized text and duplicate identifiers without changing store',
    () async {
      await store.save(page('one'));
      await expectLater(store.save(page('one')), throwsStateError);
      await expectLater(
        store.save(page('large', text: 'x' * (maxReadingCharacters + 1))),
        throwsFormatException,
      );
      await expectLater(
        store.save(page('empty', text: '   ')),
        throwsFormatException,
      );
      expect((await store.read()).single.id, 'one');
    },
  );

  test('corrupt storage is reported and never silently overwritten', () async {
    final file = File('${directory.path}/lantern-saved-reading-v1.json');
    await file.writeAsString('{broken');
    await expectLater(store.read(), throwsFormatException);
    await expectLater(store.save(page('new')), throwsFormatException);
    expect(await file.readAsString(), '{broken');
    await store.clear();
    await store.save(page('recovered'));
    expect((await store.read()).single.id, 'recovered');
  });

  test(
    'rejects overlarge files and unsupported schema before rendering',
    () async {
      final file = File('${directory.path}/lantern-saved-reading-v1.json');
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(maxReadingStoreBytes + 1);
      await handle.close();
      await expectLater(store.read(), throwsFormatException);
      await file.writeAsString(jsonEncode({'version': 99, 'pages': []}));
      await expectLater(store.read(), throwsFormatException);
    },
  );
}
