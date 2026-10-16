import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

const maxMediaBytes = 1024 * 1024;

/// Re-encode pixels without EXIF and keep both dimensions and bytes bounded.
Future<Uint8List> resizePhoto(Uint8List bytes) async {
  if (bytes.length > 20 * maxMediaBytes) {
    throw StateError('Choose a smaller photo.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final sourceWidth = descriptor.width;
  final sourceHeight = descriptor.height;
  descriptor.dispose();
  buffer.dispose();
  for (var width = 1280; width >= 256; width = (width * .7).round()) {
    final ratio = math.min(1.0, width / math.max(sourceWidth, sourceHeight));
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: math.max(1, (sourceWidth * ratio).round()),
      targetHeight: math.max(1, (sourceHeight * ratio).round()),
      allowUpscaling: false,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (data != null && data.lengthInBytes <= maxMediaBytes) {
      return data.buffer.asUint8List();
    }
  }
  throw StateError('Photo is too large after resizing. Choose another photo.');
}

class MediaDraft {
  const MediaDraft(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
  bool get isPhoto => mime.startsWith('image/');
}

/// Explicit user actions only. Does not send or automatically play media.
class MediaSession extends ChangeNotifier {
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  Directory? _directory;
  Timer? _deadline;
  StreamSubscription<void>? _completion;
  MediaDraft? draft;
  bool busy = false, recording = false, playing = false, _disposed = false;
  String error = '';
  int _epoch = 0, _playEpoch = 0;
  Future<Directory>? _directoryFuture;
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<Directory> _temp() => _directoryFuture ??= _createTemp();

  Future<Directory> _createTemp() async {
    if (_disposed) {
      throw StateError('Media session closed.');
    }
    final directory = await Directory.systemTemp.createTemp('lantern-media-');
    if (_disposed) {
      await directory.delete(recursive: true);
      throw StateError('Media session closed.');
    }
    _directory = directory;
    return directory;
  }

  Future<void> pickPhoto({required bool camera}) async {
    if (busy || recording) {
      return;
    }
    busy = true;
    error = '';
    _notify();
    try {
      final file = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (file == null || _disposed) {
        return;
      }
      if (await file.length() > 20 * maxMediaBytes) {
        throw StateError('Choose a smaller photo.');
      }
      final bytes = await file.readAsBytes();
      final encoded = await resizePhoto(bytes);
      if (!_disposed) {
        draft = MediaDraft(encoded, 'image/png');
      }
    } catch (e) {
      error = 'Photo unavailable: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> startRecording() async {
    if (busy || recording) {
      return;
    }
    final token = ++_epoch;
    busy = true;
    error = '';
    _notify();
    try {
      final recorder = _recorder ??= AudioRecorder();
      if (!await recorder.hasPermission()) {
        throw StateError('Microphone permission was not granted.');
      }
      if (_disposed || token != _epoch) {
        return;
      }
      final directory = await _temp();
      if (_disposed || token != _epoch) {
        return;
      }
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: '${directory.path}/recording.m4a',
      );
      if (_disposed || token != _epoch) {
        await recorder.cancel();
        return;
      }
      recording = true;
      _deadline = Timer(
        const Duration(seconds: 30),
        () => unawaited(stopRecording()),
      );
    } catch (e) {
      error = 'Recording unavailable: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> stopRecording({bool discard = false}) async {
    final token = ++_epoch;
    _deadline?.cancel();
    if (!recording) {
      return;
    }
    recording = false;
    busy = true;
    _notify();
    String? path;
    try {
      path = await _recorder?.stop();
      if (!discard && !_disposed && token == _epoch && path != null) {
        final file = File(path);
        if (await file.length() > maxMediaBytes) {
          throw StateError('Voice note exceeds 1 MiB.');
        }
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw StateError('No audio recorded.');
        }
        if (!_disposed && token == _epoch) {
          draft = MediaDraft(bytes, 'audio/mp4');
        }
      }
    } catch (e) {
      error = 'Recording unavailable: $e';
    } finally {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      busy = false;
      _notify();
    }
  }

  Future<void> play(Uint8List bytes) async {
    if (_disposed || bytes.isEmpty || bytes.length > maxMediaBytes) {
      return;
    }
    await stopPlayback();
    final token = ++_playEpoch;
    File? file;
    try {
      final directory = await _temp();
      if (_disposed || token != _playEpoch) {
        return;
      }
      file = File('${directory.path}/playback.m4a');
      await file.writeAsBytes(bytes, flush: true);
      if (_disposed || token != _playEpoch) {
        await _deleteFile(file);
        return;
      }
      final player = _player ??= AudioPlayer();
      _completion ??= player.onPlayerComplete.listen(
        (_) => unawaited(stopPlayback()),
      );
      await player.play(DeviceFileSource(file.path));
      if (_disposed || token != _playEpoch) {
        await player.stop();
        await _deleteFile(file);
        return;
      }
      playing = true;
      _notify();
    } catch (e) {
      await _deleteFile(file);
      if (!_disposed && token == _playEpoch) {
        error = 'Playback unavailable: $e';
        _notify();
      }
    }
  }

  Future<void> _deleteFile(File? file) async {
    try {
      if (file != null) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> stopPlayback() async {
    ++_playEpoch;
    playing = false;
    try {
      await _player?.stop();
    } catch (_) {}
    final directory = _directory;
    if (directory != null) {
      await _deleteFile(File('${directory.path}/playback.m4a'));
    }
    _notify();
  }

  void clearDraft() {
    draft = null;
    _notify();
  }

  Future<void> background() async {
    ++_epoch;
    ++_playEpoch;
    await Future.wait([stopRecording(discard: true), stopPlayback()]);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    ++_playEpoch;
    _deadline?.cancel();
    unawaited(_completion?.cancel());
    unawaited(_cleanUp());
    super.dispose();
  }

  Future<void> _cleanUp() async {
    try {
      await _recorder?.cancel();
      await _recorder?.dispose();
    } catch (_) {}
    try {
      await _player?.dispose();
    } catch (_) {}
    try {
      await _directory?.delete(recursive: true);
    } catch (_) {}
  }
}
