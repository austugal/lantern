import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/controller.dart';
import 'src/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    LanternApp(
      controller: LanternController(
        NativeTransport(),
        DeviceLocation(),
        DeviceProfile(),
      )..initialize(),
    ),
  );
}
