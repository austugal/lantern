import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'protocol.dart';
import 'services.dart';
import 'navigation.dart';

class Peer {
  const Peer(this.id, this.name);
  final String id, name;
}

class Invitation {
  const Invitation(this.peer, this.code);
  final Peer peer;
  final String code;
}

enum Delivery { sending, sent, delivered, failed }

enum WorkDecision { accepted, declined }

/// Recovery always requires a new foreground user action and fresh peer consent.
enum ReconnectReason { backgrounded, nativeStopped, peerDisconnected }

class Note {
  Note(
    this.id,
    this.text,
    this.mine,
    this.time,
    this.delivery, {
    this.expiresAt,
    this.attachmentBytes,
    this.attachmentMime,
    this.responseRequested = false,
    this.replyTo,
    this.workDecision,
  });
  final Uint8List? attachmentBytes;
  final String? attachmentMime;
  String? get attachmentKind => attachmentMime == null
      ? null
      : attachmentMime!.startsWith('image/')
      ? 'photo'
      : 'voice';
  final DateTime? expiresAt;
  final bool responseRequested;
  final String? replyTo;
  final String id, text;
  final bool mine;
  final DateTime time;
  Delivery delivery;
  WorkDecision? workDecision;
  String? deliveryDetail;
  int sendAttempts = 0;

  // A retry must not restart a disappearing message's recipient-side lifetime.
  bool get canRetry =>
      mine &&
      attachmentBytes == null &&
      expiresAt == null &&
      delivery == Delivery.failed &&
      sendAttempts > 0 &&
      sendAttempts < LanternController.maxTextSubmissions;
}

class _TextSendAttempt {
  _TextSendAttempt(this.note, this.peer, this.session);
  final Note note;
  final Peer peer;
  final int session;
  final completion = Completer<bool>();
  Timer? nativeDeadline, receiptDeadline;

  void cancel(bool submitted) {
    nativeDeadline?.cancel();
    receiptDeadline?.cancel();
    if (!completion.isCompleted) {
      completion.complete(submitted);
    }
  }
}

class RemoteLocation {
  const RemoteLocation(this.fix, this.receivedAt);
  final Fix fix;
  final DateTime receivedAt;
}

class _IncomingAttachment {
  _IncomingAttachment(this.mime, this.size, this.count, this.expiresAt);
  final String mime;
  final int size, count;
  final DateTime? expiresAt;
  final createdAt = DateTime.now();
  final chunks = <int, Uint8List>{};
}

class LanternController extends ChangeNotifier {
  LanternController(this.transport, this.location, this.store) {
    _events = transport.events.listen(
      _onEvent,
      onError: (Object e) {
        if (_disposed || (!active && !busy)) {
          return;
        }
        error = describe(e);
        unawaited(_stopNearby(reason: ReconnectReason.nativeStopped));
      },
    );
    _expiry = Timer.periodic(const Duration(seconds: 5), (_) {
      _incomingAttachments.removeWhere(
        (_, transfer) =>
            DateTime.now().difference(transfer.createdAt).inSeconds >= 120 ||
            (transfer.expiresAt != null &&
                !DateTime.now().isBefore(transfer.expiresAt!)),
      );
      final before = notes.length;
      notes.removeWhere(
        (note) =>
            note.expiresAt != null && !DateTime.now().isBefore(note.expiresAt!),
      );
      if (notes.length != before) {
        _pruneTextAttempts();
        _pruneAttachmentReceipts();
        _notify();
      }
      if (remoteLocation != null &&
          DateTime.now().difference(remoteLocation!.receivedAt).inSeconds >
              30) {
        remoteLocation = null;
        _notify();
      }
    });
  }
  final NearbyTransport transport;
  final LocationSource location;
  final ProfileStore store;
  late final StreamSubscription<Map<String, dynamic>> _events;
  late final Timer _expiry;
  StreamSubscription<Fix>? _fixes;
  Timer? _shareDeadline, _inviteDeadline;
  static const maxTextSubmissions = 3;
  static const maxPendingTextSends = 8;
  static const textSendTimeout = Duration(seconds: 10);
  static const textReceiptTimeout = Duration(seconds: 30);
  final _textAttempts = <String, _TextSendAttempt>{};
  // Future.timeout cannot cancel a native call. Keep genuinely unresolved calls
  // counted until they settle, even after a visible timeout, to bound resources.
  final _nativeTextSends = <_TextSendAttempt>{};
  int _textSession = 0;
  final _seen = <String>{};
  final _receivedTextPackets = <String, String>{};
  final peers = <String, Peer>{};
  final notes = <Note>[];
  final _incomingAttachments = <String, _IncomingAttachment>{};
  bool sendingAttachment = false;
  int _attachmentSendEpoch = 0, _attachmentSession = 0;
  static const attachmentSendTimeout = Duration(seconds: 10);
  static const attachmentReceiptTimeout = Duration(seconds: 30);
  static const maxPendingAttachmentSends = 4;
  // Keep actual platform calls counted until they settle. A Dart timeout or
  // reconnection cannot cancel them or bypass this controller-lifetime bound.
  final _nativeAttachmentSends = <Object>{};
  final _attachmentReceipts = <String, Timer>{};
  void Function(Note)? onNoteReceived;

  void _receivedNote(Note note) {
    notes.add(note);
    _trimNotes();
    // UI integrations must not be able to break packet processing.
    try {
      onNoteReceived?.call(note);
    } catch (_) {
      /* Notification hooks must not break receipt handling. */
    }
  }

  String name = '', error = '';
  bool ready = false, active = false, busy = false, sharing = false;
  bool foreground = true, _disposed = false;
  int _epoch = 0, _locationEpoch = 0;
  Peer? connected;
  ReconnectReason? reconnectReason;
  String? reconnectPeerName;
  bool get restartNeeded =>
      reconnectReason == ReconnectReason.backgrounded ||
      reconnectReason == ReconnectReason.nativeStopped;

  void dismissReconnectNotice() {
    reconnectReason = null;
    reconnectPeerName = null;
    _notify();
  }

  Invitation? invitation;
  String? requesting;
  RemoteLocation? remoteLocation;
  DateTime? shareUntil;
  int? messageLifetimeSeconds;
  bool guardianRequested = false, guardianAccepted = false;
  bool _guardianRequestPending = false, _servingGuardian = false;
  String guardianStatus = '', incomingAlert = '';
  DateTime? checkInUntil;
  Timer? _checkInTimer, _guardianDeadline;
  bool navigating = false;
  Fix? localFix;
  DateTime? localFixAt;
  final breadcrumbs = <Fix>[];
  final waypoints = <String, Fix>{};
  StreamSubscription<Fix>? _navigationFixes;
  int _navigationEpoch = 0;

  void setMessageLifetime(int? seconds) {
    if (seconds != null && ![60, 300, 900, 3600].contains(seconds)) {
      return;
    }
    messageLifetimeSeconds = seconds;
    _notify();
  }

  Future<void> requestGuardian() async {
    if (connected == null || _guardianRequestPending || guardianAccepted) {
      return;
    }
    _guardianRequestPending = true;
    final epoch = _epoch;
    final peer = connected;
    _guardianDeadline?.cancel();
    _guardianDeadline = Timer(const Duration(seconds: 35), () {
      if (_guardianRequestPending) {
        _guardianRequestPending = false;
        guardianStatus = 'Guardian request expired. Try again.';
        _notify();
      }
    });
    guardianStatus = 'Waiting for this peer to accept.';
    try {
      await _sendPacket(Packet('guardianRequest', newId(), {}));
    } catch (e) {
      if (_epoch != epoch || connected != peer) {
        return;
      }
      _guardianRequestPending = false;
      _guardianDeadline?.cancel();
      guardianStatus = 'Request failed.';
      error = describe(e);
    }
    _notify();
  }

  Future<void> respondGuardian(bool accept) async {
    if (!guardianRequested) {
      return;
    }
    guardianRequested = false;
    _servingGuardian = accept;
    try {
      await _sendPacket(
        Packet('guardianResponse', newId(), {'accepted': accept}),
      );
    } catch (e) {
      _servingGuardian = false;
      error = describe(e);
    }
    _notify();
  }

  void armCheckIn(Duration duration) {
    if (!guardianAccepted ||
        connected == null ||
        !foreground ||
        duration.inSeconds < 60 ||
        duration.inSeconds > 3600) {
      return;
    }
    _checkInTimer?.cancel();
    checkInUntil = DateTime.now().add(duration);
    guardianStatus = 'Check-in armed. Keep Lantern open and connected.';
    _checkInTimer = Timer(duration, () {
      checkInUntil = null;
      unawaited(sendSos());
    });
    _notify();
  }

  void cancelCheckIn() {
    _checkInTimer?.cancel();
    checkInUntil = null;
    guardianStatus = 'Check-in cancelled.';
    _notify();
  }

  Future<void> sendSos() async {
    if (!guardianAccepted || connected == null || !foreground) {
      guardianStatus = 'No accepted, connected guardian. Alert not sent.';
      _notify();
      return;
    }
    final epoch = _epoch;
    final peer = connected;
    try {
      // No automatic location escalation: separate location sharing remains opt-in.
      await _sendPacket(Packet('guardianAlert', newId(), {}));
      if (_epoch != epoch || connected != peer) {
        return;
      }
      guardianStatus = 'Alert submitted to connection; receipt not confirmed.';
    } catch (e) {
      if (_epoch != epoch || connected != peer) {
        return;
      }
      guardianStatus = 'Alert failed. Use another way to contact help.';
      error = describe(e);
    }
    _notify();
  }

  Future<void> startNavigation() async {
    if (navigating || !foreground) {
      return;
    }
    final epoch = ++_navigationEpoch;
    try {
      await location.authorize();
      if (epoch != _navigationEpoch || !foreground) {
        return;
      }
      navigating = true;
      _navigationFixes = location.fixes.listen(
        (fix) {
          if (!navigating || epoch != _navigationEpoch || !validFix(fix)) {
            return;
          }
          localFix = fix;
          localFixAt = DateTime.now();
          if (breadcrumbs.isEmpty ||
              vectorBetween(breadcrumbs.last, fix).distanceMeters >= 5) {
            breadcrumbs.add(fix);
            if (breadcrumbs.length > 1000) {
              breadcrumbs.removeAt(0);
            }
          }
          _notify();
        },
        onError: (Object e) {
          error = describe(e);
          unawaited(stopNavigation());
        },
        onDone: () => unawaited(stopNavigation()),
      );
    } catch (e) {
      error = describe(e);
    }
    _notify();
  }

  Future<void> stopNavigation() async {
    ++_navigationEpoch;
    navigating = false;
    localFix = null;
    localFixAt = null;
    final subscription = _navigationFixes;
    _navigationFixes = null;
    _notify();
    await subscription?.cancel();
  }

  void saveWaypoint(String name) {
    name = name.trim();
    if (localFix == null ||
        name.isEmpty ||
        name.length > 40 ||
        waypoints.length >= 50) {
      return;
    }
    waypoints[name] = localFix!;
    _notify();
  }

  void clearTrail() {
    breadcrumbs.clear();
    waypoints.clear();
    _notify();
  }

  NavigationVector? navigationTo(Fix target) =>
      localFix == null ? null : vectorBetween(localFix!, target);

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  static String describe(Object e) => e is PlatformException
      ? e.message ?? e.code
      : e.toString().replaceFirst('Bad state: ', '');
  Future<void> initialize() async {
    try {
      name = await store.read();
    } catch (e) {
      error = describe(e);
    }
    ready = true;
    _notify();
  }

  Future<void> saveName(String value) async {
    value = value.trim();
    if (value.isEmpty || value.length > 24) {
      error = 'Choose a name with 1–24 characters.';
      _notify();
      return;
    }
    try {
      await stop();
      await store.write(value);
      name = value;
      error = '';
    } catch (e) {
      error = describe(e);
    }
    _notify();
  }

  Future<void> start() async {
    if (_disposed || busy || active || !foreground || name.isEmpty) {
      return;
    }
    final epoch = ++_epoch;
    busy = true;
    error = '';
    _notify();
    try {
      await transport.call('start', {'name': name});
      if (epoch == _epoch && foreground) {
        active = true;
        if (restartNeeded) {
          reconnectReason = null;
          reconnectPeerName = null;
        }
      }
    } catch (e) {
      if (epoch == _epoch) {
        error = describe(e);
      }
    } finally {
      if (epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> stop() => _stopNearby();

  String? get _currentPeerName =>
      connected?.name ?? invitation?.peer.name ?? peers[requesting]?.name;

  Future<void> _stopNearby({ReconnectReason? reason}) async {
    if (_disposed) {
      return;
    }
    final epoch = ++_epoch;
    reconnectPeerName = reason == null
        ? null
        : _currentPeerName ?? reconnectPeerName;
    reconnectReason = reason;
    active = false;
    busy = false;
    _resetConnection();
    peers.clear();
    _notify();
    try {
      await transport.call('stop');
    } catch (e) {
      if (!_disposed && epoch == _epoch) {
        error = describe(e);
        _notify();
      }
    }
  }

  void _resetConnection() {
    _cancelTextSends();
    _cancelAttachmentSends();
    _incomingAttachments.clear();
    _guardianDeadline?.cancel();
    _checkInTimer?.cancel();
    checkInUntil = null;
    guardianRequested = false;
    guardianAccepted = false;
    _guardianRequestPending = false;
    _servingGuardian = false;
    incomingAlert = '';
    guardianStatus = 'Session ended. Check-in cancelled.';
    unawaited(stopSharing(notifyPeer: false));
    connected = null;
    invitation = null;
    requesting = null;
    remoteLocation = null;
    _inviteDeadline?.cancel();
    _seen.clear();
    notes.clear();
  }

  Future<void> request(Peer peer) async {
    if (_disposed ||
        !active ||
        !foreground ||
        connected != null ||
        requesting != null ||
        invitation != null) {
      return;
    }
    final epoch = ++_epoch;
    requesting = peer.id;
    _armInvitationTimeout();
    _notify();
    try {
      await transport.call('request', {'id': peer.id});
    } catch (e) {
      if (_disposed ||
          epoch != _epoch ||
          !active ||
          !foreground ||
          requesting != peer.id ||
          connected != null ||
          invitation != null) {
        return;
      }
      requesting = null;
      error = describe(e);
      _notify();
    }
  }

  void _armInvitationTimeout() {
    _inviteDeadline?.cancel();
    _inviteDeadline = Timer(const Duration(seconds: 35), () {
      if (connected == null && (requesting != null || invitation != null)) {
        error = 'Connection request expired. Try again.';
        unawaited(disconnect());
      }
    });
  }

  Future<void> respond(bool accept) async {
    final pending = invitation;
    if (_disposed || pending == null || !active || !foreground) {
      return;
    }
    final epoch = ++_epoch;
    invitation = null;
    requesting = accept ? pending.peer.id : null;
    _notify();
    try {
      await transport.call(accept ? 'accept' : 'reject', {
        'id': pending.peer.id,
      });
    } catch (e) {
      if (_disposed ||
          epoch != _epoch ||
          !active ||
          !foreground ||
          connected != null ||
          invitation != null ||
          requesting != (accept ? pending.peer.id : null)) {
        return;
      }
      error = describe(e);
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    if (_disposed) {
      return;
    }
    final epoch = ++_epoch;
    final id = connected?.id ?? invitation?.peer.id ?? requesting;
    reconnectReason = null;
    reconnectPeerName = null;
    _resetConnection();
    _notify();
    if (id != null) {
      try {
        await transport.call('disconnect', {'id': id});
      } catch (e) {
        if (!_disposed && epoch == _epoch) {
          error = describe(e);
          _notify();
        }
      }
    }
  }

  void _onEvent(Map<String, dynamic> e) {
    if (_disposed) {
      return;
    }
    final type = e['type'];
    if (type == 'stopped') {
      // Expected shutdown and repeated native callbacks must not replace a
      // deliberate stop or background notice with a new recovery request.
      if (!active && !busy) {
        return;
      }
      ++_epoch;
      reconnectPeerName = _currentPeerName ?? reconnectPeerName;
      reconnectReason = foreground
          ? ReconnectReason.nativeStopped
          : ReconnectReason.backgrounded;
      active = false;
      busy = false;
      peers.clear();
      _resetConnection();
      _notify();
      return;
    }
    if (!active || !foreground) {
      return;
    }
    final id = e['id'];
    if (type == 'error') {
      error = e['message'] as String? ?? 'Nearby connection failed.';
      _notify();
      return;
    }
    if (id is! String) {
      return;
    }
    switch (type) {
      case 'found':
        if (peers.length < 100) {
          peers[id] = Peer(id, e['name'] as String? ?? 'Nearby person');
        }
      case 'lost':
        peers.remove(id);
      case 'invitation':
        if (connected != null ||
            invitation != null ||
            (requesting != null && requesting != id)) {
          unawaited(_quietCall('reject', {'id': id}));
          return;
        }
        invitation = Invitation(
          Peer(id, e['name'] as String? ?? 'Nearby person'),
          e['code'] as String? ?? '',
        );
        _armInvitationTimeout();
      case 'connected':
        // Only a locally requested/accepted endpoint may enter the conversation.
        if (requesting != id || connected != null) {
          unawaited(_quietCall('disconnect', {'id': id}));
          return;
        }
        _cancelTextSends();
        _cancelAttachmentSends();
        reconnectReason = null;
        reconnectPeerName = null;
        connected = Peer(
          id,
          e['name'] as String? ?? peers[id]?.name ?? 'Nearby person',
        );
        requesting = null;
        invitation = null;
        _inviteDeadline?.cancel();
        notes.clear();
        _seen.clear();
      case 'disconnected':
        if (connected?.id == id ||
            requesting == id ||
            invitation?.peer.id == id) {
          ++_epoch;
          reconnectReason = ReconnectReason.peerDisconnected;
          reconnectPeerName =
              connected?.name ?? invitation?.peer.name ?? peers[id]?.name;
          _resetConnection();
        }
      case 'data':
        if (connected?.id != id || e['data'] is! String) {
          return;
        }
        final packet = Packet.decode(e['data'] as String);
        if (packet == null) {
          return;
        }
        if (packet.kind == 'text') {
          final acceptedPacket = _receivedTextPackets[packet.id];
          if (acceptedPacket != null) {
            // Re-ack only the exact packet previously accepted. Reusing an ID
            // with changed content must not receive a false delivery receipt.
            if (acceptedPacket != packet.encode()) {
              return;
            }
            unawaited(
              _sendPacket(
                Packet('ack', newId(), {'id': packet.id}),
              ).catchError((Object _) {}),
            );
            return;
          }
          // Never evict accepted text IDs during a session: the sender may
          // retain and retry an older note after this peer has trimmed it.
          if (_receivedTextPackets.length >= 1024) {
            error =
                'Text receipt limit reached. Reconnect to receive more texts.';
            _notify();
            return;
          }
          Note? responseTarget;
          if (packet.body['replyTo'] is String) {
            final replyTo = packet.body['replyTo'] as String;
            for (final note in notes.reversed) {
              if (note.mine &&
                  note.id == replyTo &&
                  note.responseRequested &&
                  note.workDecision == null) {
                responseTarget = note;
                break;
              }
            }
            // Never acknowledge a response that cannot be tied to a current,
            // unanswered request in this connection.
            if (responseTarget == null) {
              return;
            }
          }
          _receivedTextPackets[packet.id] = packet.encode();
          unawaited(
            _sendPacket(
              Packet('ack', newId(), {'id': packet.id}),
            ).catchError((Object _) {}),
          );
          if (responseTarget != null) {
            responseTarget.workDecision = WorkDecision.values.byName(
              packet.body['decision'] as String,
            );
            // A human response proves that this request reached the current
            // session even if its earlier app receipt was lost.
            responseTarget.delivery = Delivery.delivered;
            responseTarget.deliveryDetail = null;
            _textAttempts.remove(responseTarget.id)?.cancel(true);
          }
        } else if (!_seen.add(packet.id)) {
          return;
        }
        if (_seen.length > 512) {
          _seen.remove(_seen.first);
        }
        switch (packet.kind) {
          case 'text':
            _receivedNote(
              Note(
                packet.id,
                packet.body['text'],
                false,
                DateTime.now(),
                Delivery.delivered,
                expiresAt: packet.body['ttl'] is int
                    ? DateTime.now().add(
                        Duration(seconds: packet.body['ttl'] as int),
                      )
                    : null,
                responseRequested: packet.body['responseRequested'] == true,
                replyTo: packet.body['replyTo'] as String?,
                workDecision: packet.body['decision'] is String
                    ? WorkDecision.values.byName(
                        packet.body['decision'] as String,
                      )
                    : null,
              ),
            );
            _trimNotes();
          case 'attachmentStart':
            if (_incomingAttachments.length < 2 &&
                !_incomingAttachments.containsKey(packet.id)) {
              _incomingAttachments[packet.id] = _IncomingAttachment(
                packet.body['mime'] as String,
                packet.body['size'] as int,
                packet.body['chunks'] as int,
                packet.body['ttl'] is int
                    ? DateTime.now().add(
                        Duration(seconds: packet.body['ttl'] as int),
                      )
                    : null,
              );
            }
          case 'attachmentChunk':
            _receiveAttachmentChunk(packet);
          case 'ack':
            for (final note in notes) {
              if (note.mine && note.id == packet.body['id']) {
                note.delivery = Delivery.delivered;
                note.deliveryDetail = null;
                _textAttempts.remove(note.id)?.cancel(true);
                _attachmentReceipts.remove(note.id)?.cancel();
              }
            }
          case 'location':
            remoteLocation = RemoteLocation(
              Fix(
                (packet.body['lat'] as num).toDouble(),
                (packet.body['lon'] as num).toDouble(),
                (packet.body['accuracy'] as num).toDouble(),
              ),
              DateTime.now(),
            );
          case 'locationStop':
            remoteLocation = null;
          case 'guardianRequest':
            if (!_servingGuardian) {
              guardianRequested = true;
            }
          case 'guardianResponse':
            if (_guardianRequestPending) {
              _guardianRequestPending = false;
              _guardianDeadline?.cancel();
              guardianAccepted = packet.body['accepted'] == true;
              guardianStatus = guardianAccepted
                  ? 'Guardian accepted for this connection.'
                  : 'Guardian declined.';
            }
          case 'guardianAlert':
            if (_servingGuardian) {
              incomingAlert =
                  'Your connected peer sent an assistance alert. Contact them now.';
            }
        }
    }
    _notify();
  }

  void _receiveAttachmentChunk(Packet packet) {
    final id = packet.body['transfer'] as String;
    final transfer = _incomingAttachments[id];
    if (transfer == null) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(transfer.createdAt).inSeconds >= 120 ||
        (transfer.expiresAt != null && !now.isBefore(transfer.expiresAt!))) {
      _incomingAttachments.remove(id);
      return;
    }
    final index = packet.body['index'] as int;
    final bytes = base64Decode(packet.body['data'] as String);
    final expected = index == transfer.count - 1
        ? transfer.size - index * attachmentChunkBytes
        : attachmentChunkBytes;
    if (index >= transfer.count || bytes.length != expected) {
      _incomingAttachments.remove(id);
      return;
    }
    final existing = transfer.chunks[index];
    if (existing != null) {
      if (!listEquals(existing, bytes)) {
        _incomingAttachments.remove(id);
      }
      return;
    }
    transfer.chunks[index] = bytes;
    if (transfer.chunks.length != transfer.count) {
      return;
    }
    _incomingAttachments.remove(id);
    final assembled = Uint8List(transfer.size);
    for (var part = 0; part < transfer.count; part++) {
      assembled.setRange(
        part * attachmentChunkBytes,
        part * attachmentChunkBytes + transfer.chunks[part]!.length,
        transfer.chunks[part]!,
      );
    }
    if (!validAttachment(assembled, transfer.mime)) {
      return;
    }
    _receivedNote(
      Note(
        id,
        transfer.mime.startsWith('image/') ? 'Photo' : 'Voice note',
        false,
        now,
        Delivery.delivered,
        expiresAt: transfer.expiresAt,
        attachmentBytes: assembled,
        attachmentMime: transfer.mime,
      ),
    );
    unawaited(
      _sendPacket(Packet('ack', newId(), {'id': id})).catchError((Object _) {}),
    );
  }

  bool _currentAttachment(Note note, Peer peer, int session) =>
      !_disposed &&
      active &&
      foreground &&
      session == _attachmentSession &&
      identical(connected, peer) &&
      notes.contains(note) &&
      (note.expiresAt == null || DateTime.now().isBefore(note.expiresAt!));

  Future<void> _sendAttachmentPacket(Packet packet) {
    final token = Object();
    _nativeAttachmentSends.add(token);
    return _sendPacket(packet)
        .whenComplete(() {
          _nativeAttachmentSends.remove(token);
        })
        .timeout(attachmentSendTimeout);
  }

  void _pruneAttachmentReceipts() {
    final retained = notes.map((note) => note.id).toSet();
    for (final id in _attachmentReceipts.keys.toList()) {
      if (!retained.contains(id)) {
        _attachmentReceipts.remove(id)?.cancel();
      }
    }
  }

  void _cancelAttachmentSends() {
    ++_attachmentSession;
    ++_attachmentSendEpoch;
    sendingAttachment = false;
    for (final timer in _attachmentReceipts.values) {
      timer.cancel();
    }
    _attachmentReceipts.clear();
  }

  Future<bool> sendAttachment(Uint8List bytes, String mime) async {
    final peer = connected;
    if (_disposed ||
        peer == null ||
        !foreground ||
        !active ||
        sendingAttachment) {
      return false;
    }
    if (_nativeAttachmentSends.length >= maxPendingAttachmentSends) {
      error =
          'Attachment sends are still pending. Wait for them or restart Lantern before sending more.';
      _notify();
      return false;
    }
    if (!validAttachment(bytes, mime)) {
      error =
          'Choose a JPEG/PNG photo up to 2048 pixels or an M4A voice note, no larger than 1 MB.';
      _notify();
      return false;
    }
    final epoch = ++_attachmentSendEpoch;
    final session = _attachmentSession;
    sendingAttachment = true;
    error = '';
    final immutable = Uint8List.fromList(bytes);
    final ttl = messageLifetimeSeconds;
    final note = Note(
      newId(),
      mime.startsWith('image/') ? 'Photo' : 'Voice note',
      true,
      DateTime.now(),
      Delivery.sending,
      expiresAt: ttl == null
          ? null
          : DateTime.now().add(Duration(seconds: ttl)),
      attachmentBytes: immutable,
      attachmentMime: mime,
    );
    notes.add(note);
    _trimNotes();
    _notify();
    final count =
        (immutable.length + attachmentChunkBytes - 1) ~/ attachmentChunkBytes;
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    bool current() =>
        epoch == _attachmentSendEpoch &&
        _currentAttachment(note, peer, session);
    void requireCurrent() {
      if (!current() || !DateTime.now().isBefore(deadline)) {
        throw StateError('Attachment transfer ended before completion.');
      }
    }

    try {
      // A listener may stop or dispose Lantern during the notification above.
      requireCurrent();
      await _sendAttachmentPacket(
        Packet('attachmentStart', note.id, {
          'mime': mime,
          'size': immutable.length,
          'chunks': count,
          'ttl': ?ttl,
        }),
      );
      for (var index = 0; index < count; index++) {
        requireCurrent();
        final start = index * attachmentChunkBytes;
        final end = (start + attachmentChunkBytes).clamp(0, immutable.length);
        await _sendAttachmentPacket(
          Packet('attachmentChunk', newId(), {
            'transfer': note.id,
            'index': index,
            'data': base64Encode(immutable.sublist(start, end)),
          }),
        );
        if (index + 1 < count) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
      requireCurrent();
      if (note.delivery != Delivery.delivered) {
        note.delivery = Delivery.sent;
        _attachmentReceipts[note.id] = Timer(attachmentReceiptTimeout, () {
          _attachmentReceipts.remove(note.id);
          if (!_currentAttachment(note, peer, session) ||
              note.delivery == Delivery.delivered) {
            return;
          }
          note.delivery = Delivery.failed;
          note.deliveryDetail =
              'No attachment receipt after 30 seconds. Delivery is unconfirmed; it may already have arrived.';
          _notify();
        });
      }
      return true;
    } catch (e) {
      if (!current()) {
        return false;
      }
      // A valid app receipt can race a native rejection or submission timeout.
      // It is stronger evidence than that native result and must remain visible.
      if (note.delivery == Delivery.delivered) {
        return true;
      }
      note.delivery = Delivery.failed;
      note.deliveryDetail = e is TimeoutException
          ? 'Attachment submission timed out. Delivery is unconfirmed; it may already have arrived.'
          : 'Attachment submission failed. Delivery is unconfirmed; it may already have arrived.';
      error = describe(e);
      return false;
    } finally {
      if (epoch == _attachmentSendEpoch) {
        sendingAttachment = false;
        _notify();
      }
    }
  }

  Future<void> _quietCall(String method, Map<String, dynamic> args) async {
    try {
      await transport.call(method, args);
    } catch (_) {
      /* Late rejection during shutdown is harmless. */
    }
  }

  Future<void> _sendPacket(Packet packet) async {
    final peer = connected;
    if (peer == null || !active || !foreground) {
      throw StateError('Connect to someone first.');
    }
    await transport.call('send', {'id': peer.id, 'data': packet.encode()});
  }

  void _trimNotes() {
    // Media is memory-only; retain at most 8 MiB across the whole conversation.
    var mediaBytes = notes.fold<int>(
      0,
      (sum, note) => sum + (note.attachmentBytes?.length ?? 0),
    );
    while (mediaBytes > 8 * maxAttachmentBytes) {
      final index = notes.indexWhere((note) => note.attachmentBytes != null);
      if (index < 0) {
        break;
      }
      mediaBytes -= notes.removeAt(index).attachmentBytes!.length;
    }
    if (notes.length > 200) {
      notes.removeRange(0, notes.length - 200);
    }
    _pruneTextAttempts();
    _pruneAttachmentReceipts();
  }

  void _pruneTextAttempts() {
    for (final attempt in _textAttempts.values.toList()) {
      if (!notes.contains(attempt.note)) {
        _textAttempts.remove(attempt.note.id);
        attempt.cancel(false);
      }
    }
  }

  void _cancelTextSends() {
    ++_textSession;
    for (final attempt in _textAttempts.values) {
      attempt.cancel(false);
    }
    _textAttempts.clear();
    // Unresolved native calls are deliberately retained across reconnects.
    // A Dart timeout cannot cancel platform work, so clearing this set would
    // let each new session bypass the controller-lifetime resource bound.
    _receivedTextPackets.clear();
  }

  bool _currentTextAttempt(_TextSendAttempt attempt) =>
      !_disposed &&
      attempt.session == _textSession &&
      identical(connected, attempt.peer) &&
      identical(_textAttempts[attempt.note.id], attempt) &&
      notes.contains(attempt.note) &&
      (attempt.note.expiresAt == null ||
          DateTime.now().isBefore(attempt.note.expiresAt!));

  bool canRetry(Note note) =>
      !_disposed &&
      active &&
      foreground &&
      connected != null &&
      notes.contains(note) &&
      note.canRetry;

  bool canRespondToRequest(Note note) =>
      !_disposed &&
      active &&
      foreground &&
      connected != null &&
      notes.contains(note) &&
      !note.mine &&
      note.responseRequested &&
      note.workDecision == null;

  bool _textCapacityAvailable() {
    if (_textAttempts.length < maxPendingTextSends &&
        _nativeTextSends.length < maxPendingTextSends) {
      return true;
    }
    error =
        'Text sends are still pending. Wait for them or restart Lantern before sending more.';
    _notify();
    return false;
  }

  /// Retries are explicit and reuse the packet ID. A lost receipt may mean the
  /// peer already received the message; the receiver remembers accepted text IDs
  /// for the whole connected session.
  Future<bool> retry(Note note) async {
    if (!canRetry(note) || !_textCapacityAvailable()) {
      return false;
    }
    return _submitText(note, null);
  }

  Future<bool> respondToRequest(Note note, WorkDecision decision) async {
    if (!canRespondToRequest(note) || !_textCapacityAvailable()) {
      return false;
    }
    final response = Note(
      newId(),
      decision == WorkDecision.accepted ? 'Accepted' : 'Declined',
      true,
      DateTime.now(),
      Delivery.sending,
      replyTo: note.id,
      workDecision: decision,
    );
    note.workDecision = decision;
    notes.add(response);
    _trimNotes();
    return _submitText(response, null);
  }

  Future<bool> _submitText(Note note, int? ttl) {
    final attempt = _TextSendAttempt(note, connected!, _textSession);
    note.sendAttempts++;
    note.delivery = Delivery.sending;
    note.deliveryDetail = null;
    error = '';
    _textAttempts[note.id] = attempt;
    _nativeTextSends.add(attempt);

    void fail(String message) {
      if (!_currentTextAttempt(attempt)) {
        return;
      }
      _textAttempts.remove(note.id);
      attempt.cancel(false);
      note.delivery = Delivery.failed;
      note.deliveryDetail = message;
      _notify();
    }

    attempt.nativeDeadline = Timer(textSendTimeout, () {
      fail('Text submission timed out. Receipt is unconfirmed.');
    });
    final body = <String, dynamic>{'text': note.text, 'ttl': ?ttl};
    if (note.responseRequested) {
      body['responseRequested'] = true;
    } else if (note.replyTo != null && note.workDecision != null) {
      body['replyTo'] = note.replyTo;
      body['decision'] = note.workDecision!.name;
    }
    unawaited(
      _sendPacket(Packet('text', note.id, body)).then(
        (_) {
          final removed = _nativeTextSends.remove(attempt);
          if (!_currentTextAttempt(attempt)) {
            if (removed && !_disposed && attempt.session == _textSession) {
              _notify();
            }
            return;
          }
          attempt.nativeDeadline?.cancel();
          note.delivery = Delivery.sent;
          note.deliveryDetail = null;
          if (!attempt.completion.isCompleted) {
            attempt.completion.complete(true);
          }
          attempt.receiptDeadline = Timer(textReceiptTimeout, () {
            fail('No text receipt after 30 seconds. Receipt is unconfirmed.');
          });
          _notify();
        },
        onError: (Object e) {
          final removed = _nativeTextSends.remove(attempt);
          if (_currentTextAttempt(attempt)) {
            fail(
              'Text submission failed; receipt is unconfirmed. ${describe(e)}',
            );
          } else if (removed && !_disposed && attempt.session == _textSession) {
            _notify();
          }
        },
      ),
    );
    // Notify only after guards and deadlines exist. A synchronous listener may
    // stop or dispose the controller; that must invalidate the attempt safely.
    _notify();
    return attempt.completion.future;
  }

  Future<bool> send(String text, {bool responseRequested = false}) async {
    text = text.trim();
    if (_disposed ||
        !active ||
        !foreground ||
        connected == null ||
        text.isEmpty ||
        text.length > 1000) {
      return false;
    }
    if (responseRequested && messageLifetimeSeconds != null) {
      error = 'Turn off message expiry before requesting a work response.';
      _notify();
      return false;
    }
    if (!_textCapacityAvailable()) {
      return false;
    }
    final ttl = messageLifetimeSeconds;
    final note = Note(
      newId(),
      text,
      true,
      DateTime.now(),
      Delivery.sending,
      expiresAt: ttl == null
          ? null
          : DateTime.now().add(Duration(seconds: ttl)),
      responseRequested: responseRequested,
    );
    notes.add(note);
    _trimNotes();
    return _submitText(note, ttl);
  }

  Future<void> startSharing() async {
    if (sharing || connected == null || !foreground) {
      return;
    }
    final epoch = ++_locationEpoch;
    final peer = connected!.id;
    try {
      await location.authorize();
      if (epoch != _locationEpoch || !foreground || connected?.id != peer) {
        return;
      }
      sharing = true;
      shareUntil = DateTime.now().add(const Duration(minutes: 15));
      _shareDeadline = Timer(
        const Duration(minutes: 15),
        () => unawaited(stopSharing()),
      );
      DateTime? lastSent;
      _fixes = location.fixes.listen(
        (fix) {
          if (!sharing ||
              epoch != _locationEpoch ||
              connected?.id != peer ||
              !foreground) {
            return;
          }
          if (!validFix(fix)) {
            return;
          }
          final now = DateTime.now();
          if (lastSent != null && now.difference(lastSent!).inSeconds < 3) {
            return;
          }
          lastSent = now;
          unawaited(
            _sendPacket(
              Packet('location', newId(), {
                'lat': fix.latitude,
                'lon': fix.longitude,
                'accuracy': fix.accuracy,
              }),
            ).catchError((Object e) {
              error = describe(e);
              unawaited(stopSharing());
            }),
          );
        },
        onError: (Object e) {
          error = describe(e);
          unawaited(stopSharing());
        },
        onDone: () => unawaited(stopSharing()),
      );
      _notify();
    } catch (e) {
      if (epoch == _locationEpoch) {
        error = describe(e);
        _notify();
      }
    }
  }

  Future<void> stopSharing({bool notifyPeer = true}) async {
    final epoch = ++_locationEpoch;
    final recipient = connected?.id;
    final wasSharing = sharing;
    sharing = false;
    shareUntil = null;
    _shareDeadline?.cancel();
    final subscription = _fixes;
    _fixes = null;
    _notify();
    await subscription?.cancel();
    if (wasSharing &&
        notifyPeer &&
        recipient != null &&
        connected?.id == recipient &&
        epoch == _locationEpoch) {
      try {
        await _sendPacket(Packet('locationStop', newId(), {}));
      } catch (_) {
        /* Recipient also expires old fixes after 30 seconds. */
      }
    }
  }

  void setForeground(bool value) {
    if (_disposed || foreground == value) {
      return;
    }
    foreground = value;
    if (!value) {
      final interrupted =
          active ||
          busy ||
          connected != null ||
          requesting != null ||
          invitation != null ||
          reconnectReason == ReconnectReason.nativeStopped;
      unawaited(stopNavigation());
      unawaited(
        _stopNearby(
          reason: interrupted ? ReconnectReason.backgrounded : reconnectReason,
        ),
      );
    } else {
      // Returning to the foreground only exposes the recovery action. It never
      // restarts discovery, a connection, location sharing, or a check-in.
      _notify();
    }
  }

  void clearError() {
    error = '';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _cancelTextSends();
    _cancelAttachmentSends();
    _incomingAttachments.clear();
    onNoteReceived = null;
    ++_locationEpoch;
    _events.cancel();
    _expiry.cancel();
    _guardianDeadline?.cancel();
    _checkInTimer?.cancel();
    ++_navigationEpoch;
    _navigationFixes?.cancel();
    _fixes?.cancel();
    _shareDeadline?.cancel();
    _inviteDeadline?.cancel();
    unawaited(transport.call('stop').catchError((Object _) {}));
    super.dispose();
  }
}
