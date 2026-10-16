import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'protocol.dart';
import 'services.dart';

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

class Note {
  Note(this.id, this.text, this.mine, this.time, this.delivery);
  final String id, text;
  final bool mine;
  final DateTime time;
  Delivery delivery;
}

class RemoteLocation {
  const RemoteLocation(this.fix, this.receivedAt);
  final Fix fix;
  final DateTime receivedAt;
}

class LanternController extends ChangeNotifier {
  LanternController(this.transport, this.location, this.store) {
    _events = transport.events.listen(
      _onEvent,
      onError: (Object e) {
        error = describe(e);
        unawaited(stop());
      },
    );
    _expiry = Timer.periodic(const Duration(seconds: 5), (_) {
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
  final _seen = LinkedHashSet<String>();
  final peers = <String, Peer>{};
  final notes = <Note>[];
  String name = '', error = '';
  bool ready = false, active = false, busy = false, sharing = false;
  bool foreground = true, _disposed = false;
  int _epoch = 0, _locationEpoch = 0;
  Peer? connected;
  Invitation? invitation;
  String? requesting;
  RemoteLocation? remoteLocation;
  DateTime? shareUntil;
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
    if (busy || active || !foreground || name.isEmpty) {
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

  Future<void> stop() async {
    ++_epoch;
    active = false;
    busy = false;
    _resetConnection();
    peers.clear();
    _notify();
    try {
      await transport.call('stop');
    } catch (e) {
      error = describe(e);
      _notify();
    }
  }

  void _resetConnection() {
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
    if (!active ||
        connected != null ||
        requesting != null ||
        invitation != null) {
      return;
    }
    requesting = peer.id;
    _armInvitationTimeout();
    _notify();
    try {
      await transport.call('request', {'id': peer.id});
    } catch (e) {
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
    if (pending == null || !active) {
      return;
    }
    invitation = null;
    requesting = accept ? pending.peer.id : null;
    _notify();
    try {
      await transport.call(accept ? 'accept' : 'reject', {
        'id': pending.peer.id,
      });
    } catch (e) {
      error = describe(e);
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    final id = connected?.id ?? invitation?.peer.id ?? requesting;
    _resetConnection();
    _notify();
    if (id != null) {
      try {
        await transport.call('disconnect', {'id': id});
      } catch (e) {
        error = describe(e);
        _notify();
      }
    }
  }

  void _onEvent(Map<String, dynamic> e) {
    final type = e['type'];
    if (type == 'stopped') {
      ++_epoch;
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
          unawaited(
            _sendPacket(
              Packet('ack', newId(), {'id': packet.id}),
            ).catchError((Object _) {}),
          );
        }
        if (!_seen.add(packet.id)) {
          return;
        }
        if (_seen.length > 512) {
          _seen.remove(_seen.first);
        }
        switch (packet.kind) {
          case 'text':
            notes.add(
              Note(
                packet.id,
                packet.body['text'],
                false,
                DateTime.now(),
                Delivery.delivered,
              ),
            );
            _trimNotes();
          case 'ack':
            for (final note in notes) {
              if (note.mine && note.id == packet.body['id']) {
                note.delivery = Delivery.delivered;
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
        }
    }
    _notify();
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
    if (notes.length > 200) {
      notes.removeRange(0, notes.length - 200);
    }
  }

  Future<bool> send(String text) async {
    text = text.trim();
    if (connected == null || text.isEmpty || text.length > 1000) {
      return false;
    }
    final note = Note(newId(), text, true, DateTime.now(), Delivery.sending);
    notes.add(note);
    _trimNotes();
    _notify();
    try {
      await _sendPacket(Packet('text', note.id, {'text': text}));
      if (note.delivery == Delivery.sending) {
        note.delivery = Delivery.sent;
      }
      _notify();
      return true;
    } catch (e) {
      note.delivery = Delivery.failed;
      error = describe(e);
      _notify();
      return false;
    }
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
    foreground = value;
    if (!value) {
      unawaited(stop());
    }
  }

  void clearError() {
    error = '';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_locationEpoch;
    _events.cancel();
    _expiry.cancel();
    _fixes?.cancel();
    _shareDeadline?.cancel();
    _inviteDeadline?.cancel();
    unawaited(transport.call('stop').catchError((Object _) {}));
    super.dispose();
  }
}
