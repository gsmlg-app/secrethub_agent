# secrethub_agent

SecretHub mobile Agent embedded within Flutter applications, targeting iOS and Android. Each installed instance possesses an independent identity and connects directly to an external SecretHub Core service.

This repository is an independent Flutter plugin providing Dart entry points, Swift and Kotlin native registration, and an example application. `getPlatformVersion()` is used solely as a diagnostic to confirm native plugin registration, and does not imply that secure hardware keystores or Agent runtimes are operational. Enrollment approval, secret retrieval, offline caching, auditing, and certificate renewal are part of the target design.

Core design requirements include:

- Public Dart API paired with Swift and Kotlin native security and transport adapters.
- Non-exportable installation identity and TLS private keys, utilizing native platform keystores for mTLS.
- Configurable secret access, signed offline grants, encrypted local cache, and offline cold-start support.
- Explicit authorization lifetimes, bounded revocation latency, recovery protocols, and durable access audit logging.

The [Design Specification](DESIGN.md) documents the protocol contract with external Core services and defines 30 acceptance criteria. The prioritized milestone is verifying the vertical physical device path: native non-exportable keys → CSR → Core issuance → native mTLS WSS connection.

## Local Development

Developed using Flutter 3.47.9 stable / Dart 3.13.7. Platforms targeted are iOS 15+ and Android 9 / API 28+. The minimum iOS version aligns with current Flutter engine requirements; see the development notes for details.

```sh
flutter pub get
flutter analyze
flutter test
cd example
flutter pub get
flutter analyze
flutter test
flutter run
```

The example application demonstrates initial bootstrap status and native platform version reporting; it does not request, display, or store secrets, nor does it connect to Core. The diagnostic entry point for verifying native registration is:

```dart
import 'package:secrethub_agent/secrethub_agent.dart';

final platformVersion = await SecretHubAgent().getPlatformVersion();
```

Methods such as `start()` and `read()` described in Section 12 of `DESIGN.md` represent target interfaces to be implemented.

- [Development Environment & Vertical Path](docs/development.md)
- [Verification Evidence & Acceptance Matrix](docs/verification.md)

Core is provided by an external service project; full integration requires Core support for mobile agent capabilities. Protocol fakes, unit tests, and simulator checks are tracked separately; physical device interoperability governs final acceptance.

Refer to [Codex Development Guidelines](AGENTS.md) for scope, security constraints, and verification rules.
