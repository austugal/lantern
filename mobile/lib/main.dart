import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'src/app.dart';
import 'src/controller.dart';
import 'src/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final terms = await rootBundle.loadString('assets/LANTERN-LICENCES.txt');
    yield LicenseEntryWithLineBreaks([
      'Lantern Comms™ — ownership and legacy terms',
    ], terms);
  });
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
