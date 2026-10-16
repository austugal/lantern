import 'dart:async';
import 'package:lantern/src/services.dart';

class FakeTransport implements NearbyTransport {
  final stream = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final calls = <(String, Map<String, dynamic>?)>[];
  String? failMethod;
  @override
  Stream<Map<String, dynamic>> get events => stream.stream;
  @override
  Future<void> call(String method, [Map<String, dynamic>? args]) async {
    calls.add((method, args));
    if (method == failMethod) {
      throw StateError('Transport failed');
    }
  }

  void emit(
    String type, {
    String id = 'peer',
    String name = 'Alex',
    String code = '1234',
    String? data,
  }) {
    stream.add({
      'type': type,
      'id': id,
      'name': name,
      'code': code,
      if (data != null) 'data': data,
    });
  }
}

class FakeLocation implements LocationSource {
  final stream = StreamController<Fix>.broadcast(sync: true);
  Completer<void>? permission;
  @override
  Future<void> authorize() async {
    await permission?.future;
  }

  @override
  Stream<Fix> get fixes => stream.stream;
}

class FakeProfile implements ProfileStore {
  FakeProfile([this.name = 'Tiago']);
  String name;
  @override
  Future<String> read() async => name;
  @override
  Future<void> write(String value) async {
    name = value;
  }
}
