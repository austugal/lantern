import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class NearbyTransport {
  Stream<Map<String, dynamic>> get events;
  Future<void> call(String method, [Map<String, dynamic>? args]);
}

class NativeTransport implements NearbyTransport {
  static const _methods = MethodChannel('org.austugal.lantern/nearby');
  static const _events = EventChannel('org.austugal.lantern/events');
  @override
  Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .map((e) => Map<String, dynamic>.from(e as Map));
  @override
  Future<void> call(String method, [Map<String, dynamic>? args]) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Nearby connections require an Android phone or iPhone.',
      );
    }
    await _methods.invokeMethod<void>(method, args);
  }
}

class Fix {
  const Fix(this.latitude, this.longitude, this.accuracy);
  final double latitude, longitude, accuracy;
}

abstract class LocationSource {
  Future<void> authorize();
  Stream<Fix> get fixes;
}

class DeviceLocation implements LocationSource {
  @override
  Future<void> authorize() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on Location in your phone settings.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw StateError(
        'Location permission was denied. You can enable it in app settings.',
      );
    }
  }

  @override
  Stream<Fix> get fixes => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  ).map((p) => Fix(p.latitude, p.longitude, p.accuracy));
}

abstract class ProfileStore {
  Future<String> read();
  Future<void> write(String name);
}

class DeviceProfile implements ProfileStore {
  @override
  Future<String> read() async =>
      (await SharedPreferences.getInstance()).getString('displayName') ?? '';
  @override
  Future<void> write(String name) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      'displayName',
      name,
    )) {
      throw StateError('Could not save your name.');
    }
  }
}
