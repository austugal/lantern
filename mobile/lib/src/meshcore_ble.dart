// Copyright © 2026 Tiago Fitas. All rights reserved. See LICENSE.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'meshcore.dart';

class BleMeshRadioLink implements MeshRadioLink {
  FlutterReactiveBle? _instance;
  FlutterReactiveBle get _ble => _instance ??= FlutterReactiveBle();
  static final _service = Uuid.parse('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final _rx = Uuid.parse('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final _tx = Uuid.parse('6e400003-b5a3-f393-e0a9-e50e24dcca9e');
  final _frames = StreamController<List<int>>.broadcast();
  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<List<int>>? _notifications;
  QualifiedCharacteristic? _writeTo;
  int _epoch = 0;
  @override
  Stream<List<int>> get frames => _frames.stream;

  @override
  Stream<MeshRadio> scan() async* {
    final epoch = _epoch;
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Mobile BLE only.');
    }
    if (Platform.isAndroid) {
      await const MethodChannel(
        'org.austugal.lantern/device',
      ).invokeMethod<void>('meshPermissions');
    }
    if (epoch != _epoch) {
      return;
    }
    // Instantiation is lazy: opening Field tools never starts CoreBluetooth.
    if (_ble.status != BleStatus.ready) {
      await _ble.statusStream
          .firstWhere((s) => s == BleStatus.ready)
          .timeout(const Duration(seconds: 12));
    }
    yield* _ble
        .scanForDevices(withServices: [_service])
        .map(
          (d) => MeshRadio(
            d.id,
            d.name.isEmpty ? 'MeshCore-compatible radio' : d.name,
          ),
        );
  }

  @override
  Future<void> open(String id) async {
    await close();
    final epoch = _epoch;
    final ready = Completer<void>();
    // Canceling this subscription disconnects the GATT connection.
    _connection = _ble
        .connectToDevice(
          id: id,
          servicesWithCharacteristicsToDiscover: {
            _service: [_rx, _tx],
          },
          connectionTimeout: const Duration(seconds: 12),
        )
        .listen(
          (update) {
            if (epoch != _epoch) {
              return;
            }
            if (update.connectionState == DeviceConnectionState.connected &&
                !ready.isCompleted) {
              ready.complete();
            } else if (update.connectionState ==
                DeviceConnectionState.disconnected) {
              if (!ready.isCompleted) {
                ready.completeError(StateError('Radio disconnected.'));
              }
              _frames.addError(StateError('Radio disconnected.'));
            }
          },
          onError: (Object e) {
            if (epoch != _epoch) {
              return;
            }
            if (!ready.isCompleted) {
              ready.completeError(StateError('BLE connection failed.'));
            }
            _frames.addError(StateError('BLE connection failed.'));
          },
        );
    await ready.future.timeout(const Duration(seconds: 15));
    if (epoch != _epoch) {
      throw StateError('Canceled.');
    }
    // Reject links that cannot carry complete companion frames. Do not split
    // commands: firmware treats each characteristic write as a complete frame.
    final mtu = await _ble.requestMtu(deviceId: id, mtu: 185);
    if (epoch != _epoch) {
      throw StateError('Canceled.');
    }
    if (mtu < 179) {
      throw StateError('Radio BLE MTU is too small.');
    }
    _notifications = _ble
        .subscribeToCharacteristic(
          QualifiedCharacteristic(
            serviceId: _service,
            characteristicId: _tx,
            deviceId: id,
          ),
        )
        .listen(
          (data) {
            if (epoch == _epoch) {
              _frames.add(data);
            }
          },
          onError: (Object _) {
            if (epoch == _epoch) {
              _frames.addError(StateError('Radio notifications failed.'));
            }
          },
        );
    _writeTo = QualifiedCharacteristic(
      serviceId: _service,
      characteristicId: _rx,
      deviceId: id,
    );
  }

  @override
  Future<void> write(List<int> frame) async {
    final characteristic = _writeTo;
    if (characteristic == null || frame.isEmpty || frame.length > 176) {
      throw StateError('No usable radio connection.');
    }
    await _ble.writeCharacteristicWithResponse(characteristic, value: frame);
  }

  @override
  Future<void> close() async {
    ++_epoch;
    _writeTo = null;
    final notifications = _notifications;
    _notifications = null;
    final connection = _connection;
    _connection = null;
    await notifications?.cancel();
    await connection?.cancel();
  }
}
