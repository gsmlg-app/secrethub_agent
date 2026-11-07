# Development Guide

## Initialization Boundaries

The initial bootstrap establishes the standard Flutter plugin layout, dual-platform native registration, example app, and test harness. Native platform version diagnostics prove only method channel registration; they do not generate keys, initiate network connections, hold installation identities, or expose secret APIs.

Host applications develop locally via path dependencies:

```yaml
dependencies:
  secrethub_agent:
    path: ../secrethub_agent
```

`example/` is configured with this local path dependency. It contains no administrative logins, Core credentials, or real secrets. Enrollment approval, configured reads, origin and lifetime display, offline cold starts, and rejection/expiration handling must be integrated alongside real SDK implementations.

## Toolchain & Platform Baselines

Environment baseline recorded on 2026-11-05:

| Component | Version |
| --- | --- |
| Flutter | 3.47.9 stable, framework `c197ca5199` |
| Dart | Bundled with Flutter 3.13.7 |
| Xcode | 27.2, build `27B52` |
| Swift Compiler | 6.4.2 |
| Android SDK | 36.1.0 |
| Android Build JDK | OpenJDK 21.0.13.0.3 |
| Android Build Settings | Kotlin 2.4.0, AGP 9.1.0, Gradle 9.3.1; JVM target 17 |
| Swift Build Settings | Package tools 5.9; CocoaPods Swift language mode 5.0 |
| Plugin Target Baseline | iOS 15; Android API 28 |

Swift and Kotlin language and build settings follow the checked-in native project configurations; compiler version is distinct from Swift source language mode. The example app uses development identifiers; production bundle and application IDs are supplied by integrating host applications.

The iOS 13 baseline suggested in older design drafts was adjusted to match Flutter 3.47.9 requirements. Platform tools and `ios-arm64/Flutter.framework/Info.plist` in Flutter 3.47.9 require iOS 15 minimum; therefore, plugin podspecs, Swift Package definitions, and the example app uniformly target iOS 15, and must not claim compatibility with iOS 13 or 14.

Dart constraints are `sdk: ^3.13.7`, `flutter: >=3.47.9`. Beyond the Flutter SDK, dependencies include standard `plugin_platform_interface: ^2.0.2` (resolving to 2.1.8) and `flutter_lints: ^6.0.0`. The example app checks in `pubspec.lock` to pin resolutions; root package lockfiles are ignored per Flutter template conventions.

When running checks, prioritize using `bin/dart` bundled with the current Flutter SDK. Installing simulators is not an acceptable substitute for physical device non-exportable key or mTLS acceptance.

## First Implementation & Integration Gate

Per [DESIGN.md Sections 5, 6, 7, and 16](../DESIGN.md), the following vertical path must be completed and verified before expanding into read, cache, sync, audit, and renewal features:

1. Generate independent installation identity and TLS keys on physical iOS devices in the Secure Enclave (using `ThisDeviceOnly` and device-unlock access control); generate independent keys in the app-private Android Keystore on physical Android devices, recording actual software / TEE / StrongBox security levels.
2. Sign a CSR with the native TLS key; sign an enrollment proof for the restricted domain using the installation identity key; verify subject/SAN, challenge, CSR digest, and key independence. Include cross-language test vectors for DER ECDSA and JOSE `r || s` conversions.
3. Create and approve a mobile enrollment against a real Core service, issuing a client certificate bound to the installation public key and Agent SAN. The pending token must remain strictly in native protected storage.
4. Associate the certificate with the original Secure Enclave key's `SecIdentity` on iOS; configure an `X509KeyManager` using the Keystore private key handle on Android. Establish a native mTLS WSS connection using provisioned server trust and execute a genuine `agent:runtime` join.
5. Verify the five required mobile capabilities and certificate bindings, recording device model, OS version, plugin version, Core commit SHA, and key security level. Report any platform as blocked if genuine key handles or certificate associations are unsupported.

Before commencing integration, the integration environment must provide: a trusted Core HTTPS origin, system-trusted or controlled CA material, an approving operator, host app identifiers, and a Core version/SHA supporting the mobile protocols defined in `DESIGN.md`. Addresses such as `core.example.com` are documentation placeholders and cannot be used for deployment.

This gate must never be bypassed by using exportable PEM files, Dart software private keys, HTTP/token reads, disabled TLS verification, or relaxed capability checks. Protocol fakes provide deterministic unit testing but cannot demonstrate live Core interoperability.

## Subsequent Delivery Constraints

Full SDK delivery required by [DESIGN.md Section 16](../DESIGN.md) encompasses target Dart APIs, dual-platform native security implementations, cross-language schemas and test vectors, cache formats/migration rules, recovery procedures, and comprehensive examples. Initial bootstrap files do not imply completion of these deliverables.

Native layers must complete audit admission, grant/cache verification, and delivery checks before plaintext crosses platform channel boundaries; do not expose arbitrary signing, arbitrary URL requests, arbitrary frame dispatch, or raw secret response streams. Identity, cache, trust, and audit state must be excluded from OS backups; clearing cache does not lift known rejections, revocations, synchronization barriers, or clock invalidations.

Offline cold starts depend on a trusted OS clock and cannot defend against coordinated whole-device time and storage rollbacks. Private keys, secrets, tokens, cache keys, and secret-derived digests must never enter logs, exception messages, or example outputs.

This repository does not contain Core server code and does not deploy production services. Physical device results, builds, simulator checks, and unit tests are documented separately in the [Verification Report](verification.md).
