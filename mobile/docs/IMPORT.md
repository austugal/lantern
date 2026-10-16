# Build from the repository

Clone https://github.com/austugal/lantern and open the `mobile/` directory for Flutter work. The desktop application remains in the repository root.

Run `flutter pub get`, `flutter analyze`, and `flutter test` from `mobile/`. Build Android with `flutter build apk --debug`. iOS builds require macOS and Xcode; installation on an iPhone also requires Apple signing and provisioning.

The root `.github/workflows/mobile.yml` runs checks and native builds. GitHub write access is restored; the former archive/import workaround is no longer needed.
