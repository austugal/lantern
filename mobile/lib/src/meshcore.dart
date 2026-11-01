// Copyright © 2026 Tiago Fitas. All rights reserved. See LICENSE.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

class MeshRadio {
  const MeshRadio(this.id, this.name);
  final String id, name;
}

/// One BLE notification is one companion frame; no Lantern nearby wire format.
abstract interface class MeshRadioLink {
  Stream<MeshRadio> scan();
  Stream<List<int>> get frames;
  Future<void> open(String id);
  Future<void> write(List<int> frame);
  Future<void> close();
}

class MeshText {
  const MeshText(
    this.channel,
    this.text,
    this.seconds, {
    this.outgoing = false,
  });
  final int channel, seconds;
  final String text;
  final bool outgoing;
}

/// Small, deliberately read-only subset of radio configuration.
abstract final class MeshCodec {
  static const maxTextBytes = 100; // Leaves room for the radio's sender prefix.
  static List<int> appStart() => [
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    ...utf8.encode('Lantern'),
  ];
  static List<int> channelText(int channel, String text, int seconds) {
    final bytes = utf8.encode(text);
    if (channel < 0 ||
        channel > 39 ||
        seconds < 0 ||
        seconds > 0xffffffff ||
        text.trim().isEmpty ||
        text.contains('\u0000') ||
        bytes.length > maxTextBytes) {
      throw const FormatException(
        'Use 1–100 UTF-8 bytes without null characters.',
      );
    }
    final header = ByteData(7)
      ..setUint8(0, 3)
      ..setUint8(1, 0)
      ..setUint8(2, channel)
      ..setUint32(3, seconds, Endian.little);
    return [...header.buffer.asUint8List(), ...bytes];
  }

  static String string(List<int> bytes) {
    final end = bytes.indexOf(0);
    return utf8.decode(end < 0 ? bytes : bytes.sublist(0, end));
  }

  static MeshText? channelMessage(List<int> frame) {
    if (frame.isEmpty || frame.length > 176) {
      return null;
    }
    final offset = frame[0] == 0x08
        ? 1
        : frame[0] == 0x11
        ? 4
        : -1;
    if (offset < 0) {
      return null;
    }
    if (frame.length < offset + 7 ||
        frame[offset] > 39 ||
        frame[offset + 2] != 0) {
      throw const FormatException('Unsupported or truncated channel message.');
    }
    final seconds = ByteData.sublistView(
      Uint8List.fromList(frame),
    ).getUint32(offset + 3, Endian.little);
    final text = utf8.decode(frame.sublist(offset + 7));
    if (text.contains('\u0000')) {
      throw const FormatException('Invalid radio text.');
    }
    return MeshText(frame[offset], text, seconds);
  }
}

class MeshController extends ChangeNotifier {
  MeshController(this.link, {this.deadline = const Duration(seconds: 8)});
  final MeshRadioLink link;
  final Duration deadline;
  final radios = <String, MeshRadio>{};
  final messages = <MeshText>[];
  final _seen = <String>{};
  StreamSubscription<MeshRadio>? _scan;
  StreamSubscription<List<int>>? _frames;
  Timer? _scanTimer;
  Completer<List<int>>? _reply;
  Set<int> _expected = {};
  int _epoch = 0;
  bool _disposed = false;
  bool scanning = false, busy = false, connected = false;
  int maxChannels = 0, channel = 0, skippedMessages = 0;
  String? radioName, channelName, error;
  String status = 'Radio disconnected.';

  bool get canSend => connected && !busy && (channelName?.isNotEmpty ?? false);
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;

  Future<void> scan() async {
    if (_disposed || busy || connected || scanning) {
      return;
    }
    final epoch = ++_epoch;
    radios.clear();
    scanning = true;
    error = null;
    status = 'Scanning for 15 seconds. Select your own MeshCore radio.';
    _notify();
    _scanTimer = Timer(
      const Duration(seconds: 15),
      () => unawaited(stopScan()),
    );
    _scan = link.scan().listen(
      (radio) {
        if (!_current(epoch) || !scanning) {
          return;
        }
        if (radios.length < 32 || radios.containsKey(radio.id)) {
          radios[radio.id] = radio;
        }
        _notify();
      },
      onError: (Object _) {
        if (!_current(epoch)) {
          return;
        }
        error =
            'Bluetooth scan failed. Check Bluetooth, permissions and radio power.';
        unawaited(stopScan());
      },
      onDone: () {
        if (_current(epoch)) {
          unawaited(stopScan());
        }
      },
    );
  }

  Future<void> stopScan() async {
    scanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    final scan = _scan;
    _scan = null;
    try {
      await scan?.cancel().timeout(const Duration(seconds: 3));
    } catch (_) {
      /* Scan invalidated before awaiting. */
    }
    _notify();
  }

  Future<List<int>> _request(
    List<int> frame,
    Set<int> expected,
    int epoch,
  ) async {
    if (!_current(epoch) || _reply != null) {
      throw StateError('Radio session ended.');
    }
    final pending = Completer<List<int>>();
    _reply = pending;
    _expected = expected;
    try {
      // Attach both error handlers before writing: a radio can reply immediately.
      final values = await Future.wait<List<int>>([
        link.write(frame).then((_) => <int>[]),
        pending.future,
      ], eagerError: true).timeout(deadline);
      if (!_current(epoch)) {
        throw StateError('Radio session ended.');
      }
      return values[1];
    } finally {
      if (identical(_reply, pending)) {
        _reply = null;
        _expected = {};
      }
    }
  }

  void _onFrame(List<int> frame, int epoch) {
    if (!_current(epoch) || frame.isEmpty) {
      return;
    }
    // Do not store/log raw SELF_INFO, DEVICE_INFO or CHANNEL_INFO: they may
    // contain location, a BLE PIN or a channel secret respectively.
    final pending = _reply;
    if (pending == null || pending.isCompleted) {
      return;
    }
    if (frame.length > 176) {
      pending.completeError(const FormatException('Oversized radio frame.'));
      return;
    }
    if (frame[0] == 1) {
      pending.completeError(StateError('Radio rejected the command.'));
    } else if (_expected.contains(frame[0])) {
      pending.complete(List<int>.of(frame));
    }
    // Push notifications never trigger reads or transmissions automatically.
  }

  Future<void> connect(MeshRadio radio) async {
    if (_disposed || busy || connected || !radios.containsKey(radio.id)) {
      return;
    }
    final epoch = ++_epoch;
    busy = true;
    await stopScan();
    if (!_current(epoch)) {
      return;
    }
    error = null;
    status = 'Connecting to your radio…';
    _notify();
    _frames = link.frames.listen(
      (frame) => _onFrame(frame, epoch),
      onError: (Object _) {
        if (_current(epoch)) {
          unawaited(_fail('Radio disconnected. Reconnect manually.'));
        }
      },
      onDone: () {
        if (_current(epoch)) {
          unawaited(_fail('Radio disconnected. Reconnect manually.'));
        }
      },
    );
    try {
      await link.open(radio.id).timeout(const Duration(seconds: 20));
      if (!_current(epoch)) {
        return;
      }
      final self = await _request(MeshCodec.appStart(), {5}, epoch);
      if (self.length < 58 || self.length > 90) {
        throw const FormatException('Invalid self info.');
      }
      radioName = MeshCodec.string(self.sublist(58));
      final info = await _request([0x16, 3], {0x0d}, epoch);
      if (info.length < 80 || info[1] < 3 || info[3] < 1 || info[3] > 40) {
        throw const FormatException('Unsupported companion firmware.');
      }
      maxChannels = info[3];
      await _loadChannel(0, epoch);
      connected = true;
      status = 'Radio connected. Choose a channel; delivery is not confirmed.';
    } catch (_) {
      if (_current(epoch)) {
        await _fail(
          'Connection failed. Use compatible MeshCore BLE companion firmware, allow Bluetooth and close other radio apps.',
        );
      }
    } finally {
      if (_current(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _loadChannel(int index, int epoch) async {
    final info = await _request([0x1f, index], {0x12}, epoch);
    if (info.length != 50 || info[1] != index) {
      throw const FormatException('Invalid channel.');
    }
    // Only the slot and name survive parsing. Never expose/persist the key.
    channel = index;
    channelName = MeshCodec.string(info.sublist(2, 34));
  }

  Future<void> selectChannel(int index) async {
    if (!connected || busy || index < 0 || index >= maxChannels) {
      return;
    }
    final epoch = _epoch;
    busy = true;
    error = null;
    _notify();
    try {
      await _loadChannel(index, epoch);
    } catch (_) {
      if (_current(epoch)) {
        await _fail(
          'Could not read the channel. Reconnect before another command.',
        );
      }
    } finally {
      if (_current(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<bool> send(String text) async {
    if (!canSend) {
      return false;
    }
    final epoch = _epoch;
    final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    late List<int> frame;
    try {
      frame = MeshCodec.channelText(channel, text, seconds);
    } on FormatException catch (e) {
      error = e.message;
      _notify();
      return false;
    }
    busy = true;
    error = null;
    _notify();
    try {
      // Actual firmware returns OK (0x00), not RESP_CODE_SENT (0x06).
      await _request(frame, {0}, epoch);
      _add(MeshText(channel, text, seconds, outgoing: true));
      status = 'Accepted by radio. Recipient delivery is unconfirmed.';
      return true;
    } catch (_) {
      if (_current(epoch)) {
        await _fail(
          'Send unconfirmed; it may have transmitted. Reconnect manually and check before sending again.',
        );
      }
      return false;
    } finally {
      if (_current(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> receive() async {
    if (!connected || busy) {
      return;
    }
    final epoch = _epoch;
    busy = true;
    error = null;
    _notify();
    try {
      var count = 0;
      while (count < 20) {
        final frame = await _request([0x0a], {7, 8, 10, 16, 17, 0x1b}, epoch);
        if (frame[0] == 10) {
          break;
        }
        final message = MeshCodec.channelMessage(frame);
        if (message != null) {
          _add(message);
        } else {
          skippedMessages++;
        }
        count++;
      }
      status = count == 20
          ? 'Read 20 queued items. Tap Receive again for more.'
          : 'Radio inbox checked.';
      if (skippedMessages > 0) {
        status +=
            ' $skippedMessages unsupported items removed from the radio queue.';
      }
    } catch (_) {
      if (_current(epoch)) {
        await _fail(
          'Inbox read interrupted. Malformed messages are not displayed. Reconnect manually.',
        );
      }
    } finally {
      if (_current(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  void _add(MeshText message) {
    final key =
        '${message.outgoing}:${message.channel}:${message.seconds}:${message.text}';
    if (!_seen.add(key)) {
      return;
    }
    while (_seen.length > 200) {
      _seen.remove(_seen.first);
    }
    messages.add(message);
    if (messages.length > 100) {
      messages.removeAt(0);
    }
  }

  Future<void> _fail(String message) async {
    await disconnect();
    if (_disposed) {
      return;
    }
    error = message;
    status = message;
    _notify();
  }

  Future<void> disconnect() async {
    final epoch = ++_epoch;
    final pending = _reply;
    _reply = null;
    _expected = {};
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Disconnected.'));
    }
    connected = false;
    busy = true;
    channelName = null;
    radioName = null;
    maxChannels = 0;
    channel = 0;
    skippedMessages = 0;
    messages.clear();
    _seen.clear();
    radios.clear();
    status = 'Radio disconnected. Local conversation cleared.';
    final frames = _frames;
    _frames = null;
    await stopScan();
    await frames?.cancel();
    try {
      await link.close().timeout(const Duration(seconds: 3));
    } catch (_) {
      /* Logical session already ended. */
    }
    if (_current(epoch)) {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    super.dispose();
  }
}
