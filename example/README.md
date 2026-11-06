# SecretHub Agent example

This bootstrap app checks native plugin registration and displays the OS version.
It does not connect to Core, create identities, or read secrets. Successful
registration is not evidence of protected keys or mTLS interoperability.

From this directory:

```sh
flutter pub get
flutter run -d <ios-or-android-device-id>
```

Minimum platform versions: iOS 15 and Android 9 / API 28. The iOS minimum follows
Flutter 3.47.9. Select your own signing team in Xcode before running on iOS hardware.

For the native registration smoke test, use an explicitly selected iOS or Android
device or simulator:

```sh
flutter test integration_test/plugin_integration_test.dart -d <device-id>
```

The smoke test checks registration only. See the root DESIGN.md and development
verification documentation for the unimplemented SDK and real-device security gates.
