import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'photo re-encoding bounds portrait dimensions and preserves proportions',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 1000, 2000),
        ui.Paint()..color = const ui.Color(0xFFEEEEEE),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(1000, 2000);
      final source = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final encoded = await resizePhoto(source!.buffer.asUint8List());
      expect(encoded.length, lessThanOrEqualTo(maxMediaBytes));
      final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      expect(descriptor.height, 1280);
      expect(descriptor.width, 640);
      descriptor.dispose();
      buffer.dispose();
    },
  );

  test('oversized photo input is rejected before decoding', () async {
    await expectLater(
      resizePhoto(Uint8List(20 * maxMediaBytes + 1)),
      throwsStateError,
    );
  });

  test('media remains inert until explicit action', () async {
    final session = MediaSession();
    expect(session.recording, isFalse);
    expect(session.playing, isFalse);
    expect(session.draft, isNull);
    await session.play(Uint8List(0));
    await session.background();
    expect(session.playing, isFalse);
    expect(session.recording, isFalse);
    session.dispose();
  });
}
