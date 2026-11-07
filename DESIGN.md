# Dart / Flutter Mobile Agent Design

Date: 2026-10-29. Revision: 2026-11-05. Status: Design specification for Codex or developers creating an independent project.

Project Name: `secrethub_agent`. Target Repository: [gsmlg-app/secrethub_agent](https://github.com/gsmlg-app/secrethub_agent). This project is an independent Flutter plugin exposing a public Dart API with native iOS and Android adaptations, connecting directly to an external SecretHub Core service.

This document can be handed independently to Codex in a separate environment to initiate development from scratch; the project does not depend on the SecretHub server source tree, build system, or other server design documents. This specification contains the client-side design, the protocol contracts that the server must provide, and acceptance criteria; it does not represent already implemented features. HTTPS/WSS URLs in this document are network endpoints, and dot paths are logical secret identifiers—neither represent local filesystem paths.

The implementation environment requires the Flutter/Dart toolchain, Android build toolchain, and macOS/Xcode for iOS builds; physical device acceptance requires corresponding hardware and a Core instance implementing this protocol. Core endpoints, CA certificates, approval operators, and app identifiers are provided by the integration environment; example domains do not represent deployed services. Core internal implementation, database migrations, and administrative interfaces are the responsibility of the server project; this specification defines collaboration via external contracts. Development, commits, releases, and deployment follow authorized task instructions.

## Agent Skills

Public execution skill references are provided below; skills do not expand task authorization. All functional, security, and acceptance requirements are defined within this document and do not rely on pre-installed skill files on a particular machine.

- [verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md): Provide concrete evidence per Section 17, reporting protocol tests, simulator tests, physical device verifications, and deployment acceptance results separately.

## 1. Goals & Confirmed Requirements

Provide an Agent plugin embedded within Flutter applications. Each application installation instance possesses an independent Agent identity, connects directly to SecretHub Core, and reads authorized secrets according to configuration.

Confirmed requirements:

1. Target iOS and Android as a Flutter plugin exposing a public Dart API.
2. Each installation instance acts directly as an Agent; identity and authorization are not shared across apps via a standalone mobile daemon.
3. Identity private keys are generated and used within native platform keystores and must be non-exportable; mTLS is performed via native keystore interfaces.
4. Support online reads, encrypted offline caching, cache expiration, and bounded revocation latency.
5. Support offline cold starts: after app termination by the operating system, valid cached secrets can still be retrieved.
6. Delivery format is an independent project design specification for implementation by Codex or developers.

Version 1 covers static secrets in explicit Text and Structured formats, enrollment approval, mTLS, online reads, offline reads, certificate renewal, invalidation handling, and access auditing.

Version 1 excludes secret writing, dynamic credentials, SSH Agent, UDS listeners, cross-app sharing, Human Vault clients, standalone management apps, remote device attestation, guaranteed background execution, pub.dev publication, or production deployment. Legacy unclassified value formats are rejected without inference.

## 2. Design Defaults & Security Guarantees

The following values represent design defaults for this specification, not pre-confirmed business constraints. Implementers must establish bounded configurations according to these values; product reviews may adjust configuration defaults.

| Parameter | Default or Upper Bound | Deciding Authority |
| --- | --- | --- |
| Offline usage per secret | Disabled by default; Core policy and App config must explicitly enable | Core authorizes; App may only narrow |
| Requested offline TTL | 1 hour | App may request shorter duration |
| Core offline TTL hard cap | 24 hours | Core configuration |
| Configured paths per instance | Up to 128 | Joint limit of plugin and Core |
| Decoded data size per secret | Up to 64 KiB | Joint limit of plugin and Core |
| Single runtime JSON frame size | Up to 256 KiB, enforced pre-parsing | Native transport and Core |
| Single compact grant size | Up to 8 KiB | Native validator and Core |
| Encrypted secret cache | Up to 8 MiB, 128 items | Plugin limit; rejects new items when full, never evicts unexpired items |
| Concurrent business reads | Up to 8 | Plugin limit |
| Online read timeout | 5 seconds | App configurable within 1–30 seconds |
| Reconnect backoff | Initial 1s, max 60s, with randomized jitter | Plugin |
| Local audit backlog | Up to 10,000 entries and max 8 MiB, whichever is reached first | Native audit queue |
| Clock anomaly tolerance | 5 seconds; does not extend grant expiration | Plugin |

TLS and enrollment adhere to the Core trust boundaries defined in Section 3. Online reads require active Core authorization and durable audit persistence. Offline reads use limited-duration grants issued in advance by Core, permitting the use of corresponding cached versions within the grant's validity window.

**Offline cold starts depend on a trusted operating system and its clock.** This specification does not claim resistance against jailbreak/rooting, compromised OS kernels, or coordinated rollbacks of device system clocks and protected storage across cold starts. Rollback detection and clock high-water marks detect partial anomalies but cannot prove absolute offline time. Offline revocation latency bounds assume this clock trust condition holds. If strict time bounds independent of this condition are required in the future, trusted hardware time must be re-evaluated or offline cold starts abandoned; encrypted caching alone cannot guarantee this.

Non-exportability applies to identity private keys, TLS private keys, and native storage protection keys. Secrets returned to Dart are plaintext accessible to business logic; the plugin cannot retract copies retained by application code, nor prevent a compromised app process from invoking keys it is authorized to use.

## 3. External Service Boundaries & Compatibility Requirements

SecretHub Core is an external service responsible for PKI/CA, installation instance approvals, policies, secret storage, and auditing. This project interacts with Core strictly via the network protocols defined herein; it never calls Core internal functions or shares database access. The following constitute integration contracts:

| Scope | Server Requirements | Plugin Requirements |
| --- | --- | --- |
| Runtime Identity | Determine Agent and certificate status exclusively from verified Core-issued mTLS client certificates | Never select runtime identity via request bodies, tokens, or app identifiers |
| Instance Enrollment | Support `mobile_installation` identity kind, public key binding, manual approval, and CSR proofs | Use native installation keys; never spoof SSH host keys |
| Network Endpoints | Provide HTTPS enrollment and dedicated mTLS WSS (typically port 4665) | Connect to trusted Agent origins; never connect to admin endpoints for secret retrieval |
| Static Reads | Authorize and record audit events per current Agent, certificate, policy, and secret revision | Use `secret:read_agent`, strictly distinguishing online values from offline grants |
| Capability Negotiation | Check capabilities by registered identity kind, satisfying full Section 7 set | Declare only mobile capabilities actually supported |
| Offline Authorization | Verify `read_offline` permissions and issue bounded, identity- and payload-bound grants | Release cache only when Sections 9 and 10 admission conditions are met |
| Auditing | Support full Section 14 v2 contract, deduplication, and post-commit acknowledgments | Never misrepresent offline device observations as active Core approvals |
| Certificate Renewal | Support Section 11 CSR preparation, activation, and recovery protocols | Do not depend on 501 or unimplemented renewal endpoints |

Offline grants apply exclusively to the new mobile protocol defined herein. Other clients adopting a "re-authorize against Core on every cache delivery" model maintain their existing semantics; mobile agents must never falsely claim `uds_auth_v2`, `local_socket_read_v1`, or SSH capabilities. Server Agents require `uds_auth_v2` security level (designated floor 2); Core evaluates mobile capabilities based on identity kind without lowering floor 2 for server agents. Legacy audit v1 and existing client compatibility remain server responsibilities.

Management UI remains protected by Caddy mTLS; this plugin introduces no user accounts, registration, passwords, or separate admin authentication. Pending tokens are restricted to enrollment and cannot authorize secret reads.

Mobile capabilities described herein require corresponding Core support and are not guaranteed across arbitrary legacy Core versions. When required capabilities are absent, the plugin returns `INCOMPATIBLE_VERSION`. Protocol fakes support deterministic development but do not constitute evidence of live server interoperability.

## 4. Components & Responsibility Boundaries

The business invocation flow is: Flutter business code → Dart Agent API → Native security and transport adapters → Core.

Delivered as an independent Flutter plugin, with the recommended Dart package name `secrethub_agent`. The project comprises public Dart APIs, Swift native implementations, Kotlin native implementations, an example app, protocol test vectors, and documentation; internal layout is managed by the plugin project.

| Component | Responsible For | Does Not Hold or Decide |
| --- | --- | --- |
| Dart Agent | Configuration, state streams, Phoenix frame encapsulation, request correlation, public API, lifecycle coordination | Identity private key bytes, TLS private key bytes, Core authorization decisions |
| Native Identity | Native key generation, CSR, enrollment signing, certificate storage, key handles | Arbitrary Agent identity declarations supplied by Dart |
| Native Transport | HTTPS enrollment, runtime WSS, certificate selection, server chain and hostname verification | Downgrade policies that ignore TLS errors |
| Native Cache | Grant validation, clock verification, AEAD encryption/decryption, persistent invalidation flags, offline read admission | Modifying grant TTL or path scope |
| Native Audit | Bounded persistence, sequence generation, pre-delivery reservation, upload acknowledgment, and replay | Fabricating Core online approval records |
| Core | Approvals, identity binding, issuance, online authorization, offline grants, sync, revocation, audit ingestion | Whether the application actually consumed delivered secrets |

Data crossing the Dart-to-native boundary consists of configuration, public keys, certificates, restricted protocol frames, key references, and business read results. Exposing public APIs to export private keys, export cache encryption keys, or request arbitrary signatures is strictly prohibited.

Native security boundaries do not rely on correct Dart checks. Offline grants, invalidation flags, identity matching, and validity windows must be re-verified at the native layer; business logic bypassing Dart wrappers via platform channels cannot bypass native enforcement.

Dart may assemble protocol commands, but the native layer validates final frames, permitted events, and connection generations. Secret replies received by native transport must undergo local audit admission, grant/cache processing, and delivery checks before crossing into Dart as `SecretResult`; sending raw WebSocket frames containing plaintext to Dart and auditing post-facto is prohibited. Synchronization and invalidation messages are similarly applied natively before updating Dart state. Generic `sendFrame` methods, arbitrary HTTPS URLs, and unconstrained secret response streams do not belong in plugin bridge APIs.

## 5. Native Platform Keystores & Platform Adaptation

### 5.1 Key Roles

| Key | Lifecycle | Purpose |
| --- | --- | --- |
| Installation identity key | Stable across installation lifetime | Proves that enrollment and renewal requests originate from this installation |
| TLS client key | Rotated alongside client certificates | mTLS client authentication; distinct from the identity key |
| Cache protection key | Independent within installation | Protects offline data, grants, and integrity metadata |
| Audit protection key | Independent within installation | Protects backlog audit logs, isolating audit data from cache purges |

Signing keys for identity and TLS uniformly use P-256 / ECDSA-SHA256. Private keys are generated within native facilities; only SPKI public keys, CSRs, signatures, and certificates are exported. Pre-generating PEM private keys for import, or exporting keys temporarily to satisfy library APIs, is prohibited.

### 5.2 iOS

- Identity and TLS keys reside in the Secure Enclave via `SecKey`, with Keychain retaining references subject to app access control.
- Accessible by default only when the device is unlocked, utilizing `ThisDeviceOnly` protection, excluded from iCloud backup/sync, and avoiding per-connection Face ID prompts.
- `URLSessionWebSocketTask` carries WSS connections, providing a `SecIdentity` linked to the native key via client certificate challenge callbacks.
- CSRs and installation proofs are signed natively; certificate import matches public keys to the existing private key without importing secondary private key copies.
- Cache uses AES-256-GCM. Ephemeral data keys exist briefly in native memory and are wrapped prior to disk storage by an independent Secure Enclave wrapping key using platform-supported ECIES algorithms, without inventing proprietary cryptography. Storage keys are never reused for signatures.
- If hardware is unsupported or certificate association fails, return explicit errors; never fall back to exportable private keys. Simulators may execute protocol and UI tests but cannot serve as evidence for physical device non-exportability or mTLS acceptance.

### 5.3 Android

- Identity and TLS keys are generated in the app-private Android Keystore, retaining aliases and `PrivateKey` handles.
- Uses native TLS / OkHttp WebSocket with an `X509KeyManager` supplying the certificate chain and Keystore private key handle; keys are never copied into temporary PKCS12/BKS keystores requiring private key encoding.
- Cache and audit use distinct Keystore AES-256-GCM keys. Key operations are bound to device-unlocked states.
- Report actual key security levels, distinguishing software Keystore, TEE, and StrongBox; platform non-exportability and hardware backing are documented separately. Core does not treat client-reported security levels as remote hardware attestations.
- If Keystore fails, keys are permanently invalidated, or algorithms are unsupported, reject reads and transition to recovery; never generate fallback software private keys in Dart.

This specification suggests baseline platform targets of iOS 15 and Android 9 / API 28. (While older drafts mentioned iOS 13, Flutter 3.47.9 platform requirements establish iOS 15 as the minimum).

Core verifies public key possession and approval bindings. Version 1 does not implement App Attest, Android key attestation, or remote package authenticity proofs, and makes no claim that Core can prove hardware key residency solely via CSRs.

## 6. Installation Instances & Enrollment

### 6.1 Installation Identifier

`installation_id` is a native cryptographically secure random UUID, independent of IMEI, advertising IDs, or SSH host information. `app_identifier` is the bundle ID or application ID, used for display, grouping, and approval context, and cannot serve as an authentication credential on its own.

A non-backed-up app container installation marker is stored locally. Because iOS Keychain items may survive app uninstallation, an old Agent identity must not be reused if the container marker is missing; a new installation instance and enrollment request must be generated. Old identities and unconfirmed audit entries are quarantined independently.

Android backup rules exclude plugin identity, cache, trust state, and audit directories. If restored data exists without corresponding keys, return `IDENTITY_UNAVAILABLE`; never treat corrupted state as a fresh installation. Changing Core origins, reinstalling, or clearing app data must never migrate old grants to a new identity.

### 6.2 Enrollment Protocol

Initiate mobile enrollment requests over trusted HTTPS:

```json
{
  "identity_kind": "mobile_installation",
  "installation_id": "<uuid>",
  "identity_public_key_spki": "<base64url DER SPKI>",
  "identity_key_algorithm": "ES256",
  "platform": "ios",
  "app_identifier": "com.example.ownerapp",
  "agent_version": "<plugin version>"
}
```

The bracketed strings above denote schema descriptions, not literal values. Core validates field lengths and types strictly, verifies P-256 public keys, and computes fingerprints server-side. Non-sensitive device display names may be configured but are excluded from authentication.

Enrollment API contract:

| Method & Example URL | Input & Protection | Required Logical Result |
| --- | --- | --- |
| `POST https://core.example.com:4665/v1/agent/enrollments` | Creation payload above; requires verified server TLS | 201; `enrollment_id`, `pending_token`, `status`, `poll_interval_ms` |
| `GET https://core.example.com:4665/v1/agent/enrollments/{enrollment_id}/status` | `Authorization: Bearer <pending_token>` | Status, `agent_id`, and post-approval `required_csr_fields` |
| `POST https://core.example.com:4665/v1/agent/enrollments/{enrollment_id}/csr` | Same pending token; `csr_pem` and `identity_proof` compact JWS | `agent_id`, `certificate_pem`, `ca_chain_pem`, `certificate_serial`, `certificate_fingerprint` |
| `GET https://core.example.com:4665/v1/agent/enrollments/{enrollment_id}/connect-info` | Same pending token; certificate issued | `trusted_websocket_endpoint`, `expected_core_server_name`, `heartbeat_interval_ms`, `connect_timeout_ms` |
| `POST https://core.example.com:4665/v1/agent/enrollments/{enrollment_id}/finalize` | Same pending token; submit `status=trusted_connected` upon join | Final enrollment state; Core confirms certificate actually connected |

Polling states include `pending_registered`, `approved_waiting_for_csr`, `csr_invalid`, `certificate_issued`, `connect_info_delivered`, `trusted_connected`, `rejected`, and `expired`. `required_csr_fields` contains `subject`, `san`, `challenge`, and validity duration; the client accepts only values matching this instance, server-assigned Agent ID, and its own public key. Upon successful CSR submission, the client persists key references and certificate before initiating runtime connections.

Pending tokens reside solely in native protected storage and never enter Dart, logs, or URLs. Clients poll per server-specified intervals, respecting HTTP Retry-After headers. 401 denotes an unusable token, 404 a non-existent enrollment, and 410 expiration. Returned certificate chains, connection addresses, or CA data do not replace provisioned server trust.

Enrollment workflow:

1. Native layer validates the HTTPS origin against provisioned system trust or CA configurations.
2. Generate installation identity key; create pending enrollment; store pending token in native protected storage.
3. App state stream transitions to `pendingApproval`. Admin UI displays mobile type, public key fingerprint, app ID, and platform; operator approves and attaches Agent policies.
4. Core returns time-bounded one-time challenge and required CSR fields.
5. Native layer generates an independent TLS key and CSR, self-signing the CSR with the TLS key. The installation identity key signs the enrollment proof.
6. Core verifies pending token, approval status, challenge, proof, public key types, CSR self-signature, identity fields, and ensures keys are distinct; upon consuming the challenge, Core issues the client certificate.
7. Native layer installs the certificate, connects to the trusted runtime, and upon successful join submits `trusted_connected`.

Installation proof uses ES256 JWS compact format. Protected header specifies `alg=ES256`, `typ=secrethub-mobile-enrollment+jwt`. Payload contains `schema_version=1`, exact HTTPS `core_origin`, `enrollment_id`, `installation_id`, `challenge`, and `csr_sha256` (SHA-256 base64url of raw CSR DER). Core retrieves the verification public key from the pending enrollment record, rejecting self-declared keys in proofs.

The CSR proof JWS ECDSA signature is a 64-byte `r || s` concatenation; conversion between native DER signatures and JOSE formats requires cross-language test vectors.

Mobile certificates include `clientAuth` extended key usage, Agent URI SAN `urn:secrethub:agent:<agent_id>`, and installation key fingerprint SAN `urn:secrethub:installkey-sha256:<base64url fingerprint>`. Core verifies bindings against stored identity kind; mobile agents never emit SSH host key fields.

Plain HTTP, unauthenticated CA downloads, disabled hostname checks, or cross-origin redirects are rejected. Pending tokens or approval statuses never authorize runtime secret reads.

## 7. Runtime Connection & Capability Negotiation

Runtime WSS URL format: `wss://core.example.com:4665/agent/socket/websocket?vsn=2.0.0`, joining topic `agent:runtime`. Uses Phoenix V2 JSON serializer 5-element frames `[join_ref, ref, topic, event, payload]`. `phx_join` payload contains a `runtime_capabilities` string array without runtime identity declarations.

`phx_reply` payload contains `status=ok|error` and a `response` object. A successful join response includes `status=accepted`, negotiated `runtime_capabilities`, `agent_id`, `certificate_id`, `certificate_serial`, and `certificate_fingerprint`; the client verifies certificate bindings and mandatory capabilities. Error responses use bounded `reason` codes. `phx_close` and `phx_error` invalidate the connection.

Phoenix heartbeats transmit on topic `phoenix` with event `heartbeat` and empty payload; business `agent:heartbeat` updates Agent online presence—the two must not be conflated. Uses the negotiated heartbeat interval (default 30 seconds); connection closes and reconnects if heartbeats timeout.

Mobile capabilities:

| Capability | Definition |
| --- | --- |
| `mobile_agent_v1` | Core-registered installation identity kind |
| `agent_secret_read_v1` | Direct static reads authorized under Agent's own identity |
| `offline_secret_v1` | Signed offline grants, encrypted cache, and synchronization contract |
| `access_audit_v2` | Strict separation of online decisions and offline device observations |
| `agent_cert_renewal_v1` | CSR renewal and activation protocol |

Version 1 requires the full set above; Core omission of any required capability yields `INCOMPATIBLE_VERSION`. Legacy Core versions cannot issue grants under this protocol.

A single native coordinator manages the connection. Network handovers, app foregrounding, and timeouts trigger bounded backoff; background persistence is never assumed. Foregrounding triggers lock-state and clock refreshes, followed by connection and synchronization attempts. Each connection increments the connection generation; stale replies or canceled requests cannot fulfill new generation reads.

Successful connection enters a synchronization barrier; Section 10 synchronization must complete before online deliveries proceed.

## 8. Online Reads & Value Formats

Runtime read event: `secret:read_agent`. Core authorizes reads strictly using the socket's mTLS identity against current Agent status, certificate status, and policies; authorization, revision evaluation, and auditing execute in a strict transaction order.

Request payload schema:

```json
{
  "path": "prod.mobile.service_token",
  "known_revision": null,
  "offline_requested_ttl_seconds": 3600,
  "audit_request_id": "<uuid>",
  "audit_attempt_id": "<uuid>"
}
```

Caller-supplied identity declarations (Agent ID, app ID, certificate fingerprints) and unknown fields are rejected. Secrets use case-sensitive canonical dot paths (e.g., `prod.mobile.service_token`): 1–512 ASCII alphanumeric characters, underscores, or hyphens, separated by single dots. TTL of 0 denotes online-only; positive integers request offline grants subject to Core ceilings.

Successful response fields:

| Field | Contract |
| --- | --- |
| `status` | `value` or `not_modified` |
| `version`, `revision` | Current secret version and monotonic revision, transferred as decimal strings |
| `value_format` | `text` or `structured` |
| `authorized_at` | Server UTC timestamp of authorization |
| `payload_b64` | When `value`, contains raw UTF-8 JSON envelope encoded as base64url; omitted on `not_modified` |
| `offline_grant` | Compact JWS when authorized by policy, otherwise null |
| `offline_status` | `granted`, `not_requested`, `not_allowed`, or `unsupported_conditions` |
| `core_audit_event_id` | Core audit record UUID for this online request |
| `grant_issuance_event_id` | Issuance audit UUID when grant present; stored natively to correlate offline observations |

JSON envelope format: `{"value_format":"text","value":"..."}` or `{"value_format":"structured","value":{...}}`. Core generates deterministic JSON encoding; the native layer validates SHA-256 digests, stores, and decodes raw bytes without re-encoding. Text preserves whitespace, newlines, and JSON-shaped strings; Structured preserves full objects without stripping wrapping `value` keys.

Revisions and versions are decimal strings to prevent cross-runtime numeric precision loss. Structured business values containing large integers must not undergo silent rounding.

Core re-evaluates authorization even when `known_revision` matches. Maintaining offline cache requires a new grant binding the existing payload digest, current authorization timestamp, and renewed expiration; clients cannot extend grant lifetimes locally. If the native layer lacks a payload matching `not_modified`, it retries a full read under a new attempt ID.

When offline authorization is denied by policy, valid online reads still return values with explicit `offline_status`. Policy outcomes of `not_allowed` or `unsupported_conditions` persist a local path block and invalidate older grants without rejecting the current online value. APIs requesting offline prefetching mark ungranted items as prefetch failures.

## 9. Offline Authorization, Validity, & Persistence

### 9.1 Offline Authorization as Independent Capability

Core evaluates explicit `read_offline` permissions and positive integer `offline_max_ttl_seconds` only after general `read` access is granted. Offline access is disabled by default; general read permission never implies offline permission.

Example policy:

```json
{
  "version": "1.1",
  "allowed_secrets": ["prod.mobile.service_token"],
  "allowed_operations": ["read", "read_offline"],
  "conditions": {}
}
```

Core policy models maintain independent `offline_max_ttl_seconds` attributes distinct from dynamic lease TTLs. Policies omitting `read_offline` retain their existing semantics. Policies are evaluated server-side; client configurations cannot grant themselves permissions.

Offline issuance requires that authorizations do not depend on real-time conditions unverifiable offline (e.g., client IP, real-time rate limits, session state, or dynamic time windows). Version 1 rejects offline grant issuance when such conditions exist, while allowing standard online reads to proceed. Explicit denies, corrupted policies, invalid certificates, sealed Vaults, or unavailable audit backends prevent grant issuance.

Effective expiration is the earliest of:

```text
issued_at + requested_offline_ttl
issued_at + applicable_offline_policy_max_ttl
issued_at + agent_offline_max_ttl
issued_at + core_offline_hard_cap
runtime_certificate.not_after
offline_signing_key.not_after
secret explicit expiration timestamp (if present)
```

Multiple matching offline allow policies evaluate to the minimum TTL; any matching deny takes precedence. Core/Agent ceilings and App requests can only narrow the TTL. Once expiration is reached, access expires immediately without network-failure grace periods. Policy changes do not rewrite already issued grants; retracting authorization requires invalidation messages or awaiting expiration.

### 9.2 Grant Format & Signature Trust

Core signs JOSE-standard ES256 compact JWS tokens using a dedicated P-256 offline signing key protected by Vault, separate from CA keys, TLS keys, or audit HMAC keys. Header specifies `alg=ES256`, `typ=secrethub-offline-grant+jwt`, and a `kid` referencing a trusted key. Plugins verify signatures natively.

Payload bindings:

| Field | Type & Definition |
| --- | --- |
| `schema_version` | Constant integer 1 |
| `iss` | Persistent `core_instance_id` |
| `aud` | Constant `secrethub-mobile-offline` |
| `jti` | Unique grant UUID |
| `core_origin` | Exact trusted Agent HTTPS origin |
| `agent_id`, `installation_id` | Assigned Agent ID and installation UUID |
| `identity_key_fingerprint` | SHA-256 base64url of installation SPKI DER |
| `certificate_id` | Runtime certificate UUID active at issuance |
| `path` | Canonical dot path |
| `version`, `revision` | Positive integer decimal strings |
| `value_format` | `text` or `structured` |
| `payload_sha256` | SHA-256 base64url of raw payload bytes |
| `authorization_epoch` | Authorization epoch at issuance |
| `iat`, `nbf`, `exp` | Unix seconds; `nbf=iat`, `exp>iat` |
| `clock_mode` | Constant `trusted_system_clock_v1` |

Grants are local authorization tokens bound to a specific installation, path, and version; they are never valid Core HTTP bearer tokens.

Signing public key bundles are distributed exclusively via verified enrollment or runtime sync and stored in integrity-protected native storage alongside `core_instance_id`, origin, and installation identity. `jku` headers, embedded keys, arbitrary key URLs, or algorithm switching are rejected; unknown `kid` values require online trust refresh.

Signer key rotation distributes verification keys before issuing new grants; retired keys are retained until all dependent grants expire. Clients track bundle generations and reject generation rollbacks.

### 9.3 Native Cache Architecture

Cached items encapsulate the full grant, raw payload bytes, Core scope, and identity bindings using AES-256-GCM (96-bit random nonce, 128-bit tag). Nonces are never reused.

Associated data (AAD) includes schema version, Core scope, installation ID, canonical path, revision, and grant ID, all matching verified signature claims. Cache files use hashed or escaped storage keys to prevent path traversal.

Writes execute via temporary files, fsync, and atomic replacement; grants and payloads persist prior to becoming readable. Crash recovery accepts only intact, verified files. If cache writes fail during an online read, the online value is returned to callers while marking SDK `offlineAvailability` as `cacheWriteFailed`.

Trust bundles, clock high-water marks, known rejections, revision lower bounds, and sync-required flags reside in separate integrity-protected state unaffected by cache flushes. Clearing cache cannot lift revocations or resurrect invalid grants.

Cache, identity, trust, and audit state are excluded from OS backups and cloud synchronization. Sensitive material never enters logs, crash reports, clipboards, or shared preferences.

### 9.4 Offline Read Admission

Offline deliveries execute the following sequential native checks:

1. Device is unlocked and keystore keys are accessible; Core scope matches current installation.
2. Alias is configured and explicitly permits offline access; path matches grant.
3. No active revocations, rejections, TLS trust failures, sync barriers, or recovery states exist.
4. Grant algorithm, signing key, signature, claims, and local bindings validate successfully.
5. Current time satisfies `nbf <= now < exp`; runtime certificate remains unexpired.
6. AEAD decryption succeeds; payload digest, format, and revision match grant and meet or exceed local revision lower bounds.
7. Audit queue reserves capacity and writes admission and release intent events.
8. Deliver secret value with `source=offline`, revision, last authorization timestamp, and expiration to Dart.

Delivery checks and invalidation writes are serialized. Invalidation persistence takes precedence over pending reads; in-flight reads re-verify generation prior to release intent.

### 9.5 Offline Cold Start & Clock Trust Model

During trusted sync, Core supplies server time. The native layer persists server anchor `S0`, device wall clock `W0`, monotonic clock `M0`, and highest observed valid time `H`. Computations use milliseconds; comparisons against `exp * 1000` allow no grace period expansion.

Within a single session, candidate time is `S0 + (Mnow - M0)`, with wall-clock estimate `S0 + (Wnow - W0)`. Effective time evaluates to `max(candidate, wall_estimate, H)`; anomalies trigger an immediate clock block.

Monotonic time tracking includes device sleep intervals and correlates against wall clocks; Dart timers pausing during app suspension cannot serve as TTL clocks. Backward clock shifts exceeding 5 seconds, abnormal drift, or unexplained monotonic resets persist a `CLOCK_UNTRUSTED` state requiring online sync.

On cold start:

- Validate cache, identity, trust, and control state; compute estimated time `max(S0 + (Wnow - W0), H)`.
- If wall clock estimate is earlier than `H` beyond tolerance, reject access. Advancing clocks past expiration permanently expires grants.
- When native platforms can confirm boot cycles, monotonic anchors enhance validation; otherwise, adhere to the standard OS clock trust model.
- Absence of trusted time anchors, storage corruption, or detected clock tampering blocks offline reads.
- Clock high-water marks persist before secret delivery; process crashes cannot revert to earlier timestamps.

Mobile hardware does not provide hardware anti-rollback clocks. Documentation must retain this boundary and never portray a 24-hour limit as an unconditional revocation guarantee independent of OS integrity.

## 10. Network Disconnection, Reconnection, & Invalidation Handling

### 10.1 Read Modes & Failure Classification

| Mode | Behavior |
| --- | --- |
| `onlineOnly` | Demands fresh Core authorization; failures never return offline cache |
| `preferOnline` (default) | Attempts online read first; explicit network unreachability, connection drop, or timeout falls back to valid offline grants |
| `offlineOnly` | Performs no network requests; executes all native admission checks |

`offlineOnly` cannot bypass known Core rejections, sync barriers, or clock anomalies. Local configurations can only narrow TTLs (`iat + local_max_age`); subsequent configuration increases cannot revive invalidated grants.

Authoritative rejections (permission denied, Agent/certificate revoked, secret deleted, version incompatible, Vault sealed, audit down) never fall back to offline cache and persist scope blocks. Unknown server errors or TLS failures similarly forbid offline fallback.

### 10.2 Synchronization Barrier

Upon joining the runtime, the native layer persists `sync_required=true`, pauses cache deliveries, and dispatches `agent:sync`. The request lists up to 128 configured paths with optional cached grant IDs, revisions, and existing block states, alongside client bundle generations, omitting secret values and digests. Blocked paths without cache also participate in sync.

Core re-evaluates Agent status, certificate status, authorization gates, Vault readiness, and audit state; it checks permissions and latest revisions for each item.

Sync replies return server time, Core instance ID, bundle generation, current authorization epoch, online/offline permissions per item, and grant disposition (`retain` / `invalidate`). `retain` does not extend the original grant expiration.

The client persists all invalidations, scope blocks, trust, and clock updates before lifting the barrier; partial results or write failures preserve the barrier. Core returns smaller epoch or generation values trigger `CORE_STATE_ROLLBACK`. Once joined, interrupted sync requires re-synchronization before cache release resumes; prior to an initial join, existing valid grants remain accessible under offline rules.

### 10.3 Revocation, Policy Changes, & Rotation

Core transmits `agent:invalidate` with generation, scope, path/grant ID, and bounded reason; the SDK persists updates before acknowledging. Invalidation messages support out-of-order and duplicate delivery, and are cumulative; lifting invalidations requires full trusted synchronization. Disconnections do not constitute revocation notices.

Agent/certificate revocations, policy denials, offline permission removal, secret deletion, and rotations follow identical invalidation paths. Rotation advances local revision watermarks; connected clients flush old revisions, while offline devices may continue using existing grants until expiration.

Subject to Section 2 clock trust conditions, revocation latency is bounded by the earlier of invalidation application or grant expiration. Immediate revocation cannot be guaranteed to offline devices.

## 11. Certificate Renewal & Identity Recovery

Certificate TTL is determined by Core policy; clients attempt renewal when reaching ~70% of certificate lifetime during online execution. Background execution is not guaranteed. Offline grant lifetimes cannot exceed the certificate validity window at issuance.

Runtime RPCs for renewal:

1. `agent:certificate_challenge`: Generates a renewal ID and nonce bound to Agent and certificate ID (5-minute TTL).
2. `agent:certificate_renew`: Submits new native TLS CSR and installation identity proof. Proof binds origin, renewal ID, nonce, old certificate ID, and CSR digest under header `secrethub-mobile-renewal+jwt`.
3. `agent:certificate_activate`: Client persists new key references and certificate, requesting atomic activation.

Renewals are idempotent under matching renewal IDs and CSRs; mismatched CSRs return conflicts. Prepared certificates cannot authorize secret reads. Activation atomically switches active certificates, invalidates prior certificates, records audit logs, and disconnects older runtimes within a single Core transaction.

Clients persist activation state and suspend old grant delivery before sending activation requests. If responses are lost, clients attempt connection under the new identity; if unswitched, they retry activation over the existing connection. Both paths verify identical server trust. When both recovery attempts fail, the activation state is retained under bounded retry. Upon successful activation, the new certificate completes synchronization and retrieves fresh grants; old grants are retired.

Expired certificates cannot renew over expired mTLS. Clients must initiate a challenged recovery enrollment using the existing installation identity key, requiring operator approval. Revoked or suspended identities require manual operator handling.

Key loss or permanent invalidation halts operations, retains unconfirmed audit backlogs, and transitions to `needsRecovery`. Offline cold starts consume only unexpired grants without extending trust.

## 12. Dart API & Configuration Contract

Target API design:

```dart
final agent = SecretHubAgent(
  config: AgentConfig(
    coreUrl: Uri.parse('https://core.example.com:4665'),
    trust: AgentTrust.system(),
    secrets: {
      'serviceToken': SecretBinding(
        path: 'prod.mobile.service_token',
        offline: OfflineAccess.allow(maxAge: Duration(hours: 1)),
      ),
      'liveConfig': SecretBinding(
        path: 'prod.mobile.live_config',
        offline: OfflineAccess.deny(),
      ),
    },
  ),
);

await agent.start();
final subscription = agent.states.listen(renderAgentStatus);

final token = await agent.read('serviceToken');
final cached = await agent.read(
  'serviceToken',
  mode: ReadMode.offlineOnly,
);
final report = await agent.prefetch(['serviceToken']);

await subscription.cancel();
await agent.close();
```

| Method | Contract |
| --- | --- |
| `start()` | Returns upon local initialization and coordinator startup; does not block on manual approval; cold start may enter `readyOffline` |
| `states` | Bounded, deduplicated state stream; never carries secrets or tokens |
| `read(alias, mode)` | Restricted to configured aliases; returns value, revision, source, and authorization timestamps, or typed errors |
| `prefetch(aliases)` | Fetches and persists offline grants online; reports per-item status (`prepared` only on durable disk commit) |
| `clearCache(aliases)` | Removes payloads and grants; preserves control state, rejections, revision floors, and audit trails |
| `close()` | Cancels timers, closes connections, flushes state; does not unenroll Agent or delete identities |

`SecretResult` contains `value`, `valueFormat`, `version`, `revision`, `source` (online/offline), `authorizedAt`, nullable `offlineExpiresAt`, and `offlineAvailability`. The latter reflects `prepared`, `notRequested`, `notAllowed`, `unsupportedConditions`, or `cacheWriteFailed`. `authorizedAt` on offline results reports original grant issuance time. Default `toString()` implementations must sanitize secrets.

App configuration includes origins, trust options, display metadata, alias-to-path mappings, timeouts, and cache rules. Private keys, bootstrap tokens, or long-lived credentials never enter source code or assets.

A single coordinator instance manages each installation scope; all Dart isolates share native state. Redundant coordinator launches return errors.

### 12.1 Internal Dart-to-Native Bridge Contract

Internal bridge operations utilize opaque native handles:

| Operation | Input | Return & Boundary |
| --- | --- | --- |
| `identity.loadOrCreate` | Verified Core scope, installation markers, display metadata | Identity reference, SPKI, fingerprint, key protection metadata; corrupted state is never auto-rebuilt |
| `identity.prepareCsr` | Core-required subject/SAN, enrollment/renewal reference | CSR DER and new TLS key reference; enforces constraints natively |
| `identity.proveEnrollment` / `proveRenewal` | Flow reference and Core challenge | Domain-restricted JWS; CSR digest computed natively |
| `enrollment.request` | Bounded enrollment operations and fields | Security status/certificates; pending token retained natively |
| `runtime.open` | Scope, installed certificate/key references, generation | Connection handle and security events; prepared certificates cannot read secrets |
| `runtime.request` | Whitelisted events, bounded payloads, correlation IDs, generation | Control replies or verified `SecretResult`; audit capacity reserved prior to delivery |
| `cache.read` | Alias/path binding, correlation ID, local maxAge | Full admission execution returning `SecretResult`; arbitrary blob decryption APIs are forbidden |
| `cache.clear` | Alias list within current scope | Deletes values/grants while preserving control state and audit |
| `audit.nextBatch` / `applyAck` | Bounded batch requests or verified Core ack references | Sanitized event batches; unconfirmed records cannot be purged via Dart-constructed ID lists |
| `runtime.close` | Connection reference | Closes connections and flushes state without unregistering identities |

Native layers validate real-connection sync, invalidations, and audit acks directly. Bridge schemas, error codes, and test vectors are shared across iOS, Android, and Dart.

## 13. Lifecycle States, Errors, & Retries

State definitions:

| State | Permitted Business Behavior |
| --- | --- |
| `unregistered` / `enrolling` / `pendingApproval` | Display progress; secret reads disallowed |
| `connecting` | Prior to join, existing grants meeting offline admission remain usable |
| `syncing` | Synchronization barrier active; cache deliveries suspended |
| `readyOnline` | Online reads permitted; `offlineOnly` requires valid grants |
| `readyOffline` | At least one cached secret is readable offline |
| `locked` | Keystore unavailable; plaintext deliveries rejected |
| `needsRecovery` / `revoked` / `incompatible` | Reads rejected with explicit recovery/upgrade context |
| `closed` | Operations terminated; coordinator must be recreated to restart |

Error classifications:

| Error Code | Auto Retry | Offline Fallback Permitted |
| --- | --- | --- |
| `NETWORK_UNAVAILABLE`, `CONNECTION_CLOSED`, `REQUEST_TIMEOUT` | Bounded backoff | Permitted if valid grant exists without blocks |
| `PENDING_APPROVAL` | Low-frequency foreground poll | Disallowed |
| `PERMISSION_DENIED`, `SECRET_NOT_FOUND` | No auto-retry | Disallowed; persists path block |
| `IDENTITY_REVOKED`, `CERTIFICATE_EXPIRED` | Explicit recovery | Disallowed; invalidates identity |
| `TLS_UNTRUSTED`, `IDENTITY_UNAVAILABLE`, `KEY_INVALIDATED` | No software fallback | Disallowed |
| `CLOCK_UNTRUSTED`, `OFFLINE_GRANT_EXPIRED`, `OFFLINE_NOT_PREPARED` | Re-sync on reconnection | Disallowed |
| `CACHE_INTEGRITY_FAILED`, `PAYLOAD_UNSUPPORTED` | Quarantines bad entry | Disallowed |
| `VAULT_SEALED`, `AUDIT_UNAVAILABLE`, `INCOMPATIBLE_VERSION` | Awaits state change | Disallowed |
| `CORE_STATE_ROLLBACK` | Operator review | Disallowed; preserves highest local state |
| `RATE_LIMITED` | Honors Retry-After | Disallowed |

Requests carry UUIDs; attempts carry independent UUIDs. Futures complete exactly once.

## 14. Access Audit Contract

Employs an observational model: admission, attempt, release intent, response sent/failed. Core decisions and Agent delivery observations are recorded separately. Offline reads record local device observations under existing grants and never forge Core online decisions.

### 14.1 Schema v2

`access_audit_v2` field whitelist:

| Field | Type & Constraints |
| --- | --- |
| `schema_version` | Required, constant integer 2 |
| `event_id`, `producer_id`, `request_id` | Required UUIDs; producer ID bound to persistent queue |
| `producer_sequence` | Required monotonic positive integer, max `9007199254740991` |
| `source` | Required; plugin uploads set to `agent`; `core` generated server-side |
| `phase` | Required, closed enumeration below |
| `observed_at` | Required UTC ISO 8601 string, max 40 bytes |
| `identity_status`, `attribution` | Required; mobile set to `unverified`, `none` |
| `operation` | Required; `read`, `invalid`, or `authenticate` (secret reads use `read`) |
| `outcome` | Required; `success`, `denied`, `error`, or `unknown` |
| `reason_code`, `cache_status` | Required closed enumerations |
| `attempt_id` | Nullable UUID; mandatory during attempt, decision, release, and send phases |
| `agent_id` | Nullable identifier (1–128 ASCII bytes) |
| `application_id` | Mobile sets to constant null |
| `secret_id`, `policy_id`, `core_event_id`, `client_correlation_id` | Nullable UUIDs |
| `secret_path` | Nullable canonical dot path |
| `secret_version`, `policy_version` | Nullable exact positive integers, max `9007199254740991` |
| `duration_us` | Nullable non-negative integer, max `9007199254740991` |

Offline extension fields:

| Field | Definition |
| --- | --- |
| `authorization_mode` | `online` or `offline_grant` |
| `grant_id` | Validated grant UUID |
| `secret_revision` | Decimal string revision |
| `grant_expires_at` | Validated grant UTC expiration timestamp |
| `grant_issuance_event_id` | Core event UUID from grant issuance |

`authorization_mode` is mandatory in v2. Cached deliveries require `grant_id`, `grant_expires_at`, and `grant_issuance_event_id`.

Allowed Agent phases: `admitted`, `attempt`, `release_intent`, `response_sent`, `response_failed`, `rejected`. Outcomes for `admitted`, `attempt`, and `release_intent` are `unknown`; `response_failed` is `error`; `rejected` is `denied` or `error`.

`cache_status` values: `none`, `miss`, `hit`, `validated`, `invalidated`, `offline`.

Allowed `reason_code` values:

```text
none allowed permission_denied unauthorized invalid_request invalid_identity
invalid_application invalid_principal invalid_revision invalid_path incompatible_version
revoked disabled expired not_found secret_not_found core_unavailable authorization_unavailable
audit_unavailable sealed timeout transport_error response_error internal_error unsupported_schema
invalid_event event_conflict journal_full journal_corrupt proof_required proof_failed
certificate_invalid connection_closed rate_limited offline_grant_valid offline_grant_expired
clock_untrusted cache_integrity_failed
```

Events omit secret values, payloads, grant tokens, signatures, private keys, and secret-derived digests. Maximum event size is 4,096 bytes; batches contain up to 100 events and 131,072 bytes via `audit:batch`. Acknowledgments confirm events only after database commit.

### 14.2 Local Persistence & Forwarding

Queues use independent encrypted storage, persistent producer UUIDs, and monotonic sequences. Admissions reserve capacity; queue failures return `AUDIT_UNAVAILABLE`. Cache evictions never clear audit logs.

Offline release intents persist prior to plaintext crossing native boundaries. Reconnecting clients process invalidations before flushing audit backlogs.

## 15. External Core Collaboration Requirements

Logical server-side requirements:

| Domain | Required Logical Data & Constraints |
| --- | --- |
| Agent / Enrollment | `identity_kind`, installation UUID, SPKI public key/fingerprint, app ID, platform |
| Certificate Metadata | Installation key SAN, preparation/activation bindings, renewal ID |
| Policy | `read_offline` operation and `offline_max_ttl_seconds` attribute |
| Core Identity | Stable `core_instance_id`, preserved across logical restorations |
| Offline Signing Keys | Key ID, public key, validity, generation, Vault-protected private key |
| Offline Grants | Unique grant ID, Agent/installation/certificate, path/revision, epoch, timestamps, signer ID, issuance audit ID |
| Renewal | Renewal ID, old certificate, new CSR digest, prepared certificate, status |
| AccessAudit | v2 event validation, persistence, projections, and source separation |

Offline grant authorization, revision lookup, grant metadata, and audit persistence share an atomic transaction serialized against policy changes. Upgrades deploy Core first, followed by plugins, before operators enable offline policies on specific paths.

## 16. Independent Project Deliverables & Development Boundaries

Delivered as a standard Flutter plugin providing Dart packages, iOS/Android registration, tests, and example apps. The plugin does not bundle Core services.

Deliverables include: public APIs and configuration docs; enrollment and recovery guides; cross-language schemas and test vectors; cache format and migration specifications; native implementations; secure example apps; and Section 17 verification evidence.

Development responsibilities:

| Responsibility | Deliverable | Pre-Integration Evidence |
| --- | --- | --- |
| Protocol / Core | Mobile identity, direct reads, offline policies/grants, sync, renewal, audit v2 | Consistent protocol vectors, Core authorization regressions |
| Dart | Config, public API, Phoenix serializer, ref/generation tracking, error mapping | Fake transport deterministic state and concurrency tests |
| iOS | Secure Enclave keys, CSR, SecIdentity, native WSS, cache and audit persistence | Physical device non-exportability and genuine Core mTLS WSS link |
| Android | Keystore, native key manager/WSS, cache and audit persistence | Physical device security levels and genuine Core link |
| Integration Acceptance | Example app, device testing guide, protocol docs, final report | Matrix evidence across all 30 acceptance criteria |

The vertical path (native keys → CSR → Core issuance → native mTLS WSS) must be proven on physical hardware first.

## 17. Acceptance Criteria

Implementers must record concrete evidence for each criterion:

| ID | Scenario | Required Observation |
| --- | --- | --- |
| AC-01 | Two instances of same App | Independent keys, Agent identities, policies, and caches; mutual grant exchange rejected |
| AC-02 | Initial enrollment & pre-approval | Explicit pending state; no secret or offline grant delivery prior to operator approval |
| AC-03 | CSR substitution & challenge replay | Core rejects; CSR private key possession and distinct key constraints enforced |
| AC-04 | iOS physical device mTLS | Secure Enclave key executes CSR, certificate association, and live WSS join; Dart holds zero private key bytes |
| AC-05 | Android physical device mTLS | Keystore handle executes live WSS join; non-exportable check and recorded security level |
| AC-06 | Key facility unavailable or invalidated | Explicit failures; no software, PEM, or token fallbacks |
| AC-07 | Floor 2 & legacy client regression | Honest mobile capability negotiation; server Agent UDS floor 2 regressions remain sound |
| AC-08 | Online authorization & authoritative rejection | Inherits genuine Core outcomes; rejections are never overridden by offline cache |
| AC-09 | Text / Structured, newlines, `value` key | Values and formats preserved without distortion; legacy formats rejected |
| AC-10 | Missing read_offline or TTL | Online read succeeds; offline grant omitted; prefetch reports unprepared |
| AC-11 | Real-time policy conditions offline | Grants rejected when IP/time conditions exist, preserving online evaluation |
| AC-12 | TTL boundaries & certificate expiration | Minimum truncation enforced; immediate rejection at `exp` boundary without grace |
| AC-13 | Network disconnection & timeout | `preferOnline` returns valid offline secret with authentic authorization timestamp |
| AC-14 | Cold start after OS app termination | Reading unexpired cached secret succeeds using native state, trusted clock, and audit |
| AC-15 | Suspension & deep sleep | Sleep time counted toward TTL; expired cache rejected upon wake |
| AC-16 | Clock rollback & corrupted anchors | Detected anomalies trigger persistent blocks; no claims of resisting whole-device rollback |
| AC-17 | Cache & grant tampering | AEAD, signature, binding, digest, and high-water mark checks reject tampered data |
| AC-18 | Interrupted writes, full disk, full queue | Atomic cache recovery; pre-delivery audit capacity enforcement prevents data loss |
| AC-19 | Offline attempt following online rejection | Persistent rejection overrides old grants; clearing cache does not lift blocks |
| AC-20 | Offline revocation / rotation | Grants live only until expiration under clock trust assumptions; post-reconnect sync invalidates |
| AC-21 | Partial sync response or dropped connection | Synchronization barrier remains active; successful socket handshake alone does not release cache |
| AC-22 | Signer rotation & bundle rollback | New signer key pre-distributed; generation rollback rejected; old grants live only until expiration |
| AC-23 | Renewal activation & crash recovery | Idempotent recovery to unambiguous certificate state; no automatic fallback to old identity |
| AC-24 | Certificate expiration & identity revocation | Expired mTLS/grants/tokens cannot renew; operator recovery approval boundary enforced |
| AC-25 | Audit backlog, replay, conflicts, drops | Pre-delivery persistence, post-commit confirmation, deduplication, and conflict evidence preservation |
| AC-26 | Native delivery boundary crash | `unknown` observation preserved; no false claims of business use and no automatic secret re-dispatch |
| AC-27 | Uninstalled keychain residue & backup restore | New iOS installation isolated; Android missing key rejected; old audit records not falsely reported |
| AC-28 | Multiple isolates & connection race conditions | Single coordinator, generation isolation, canceled/delayed response handling, Future completes once |
| AC-29 | Sensitive material leakage audit | Verify logs, error text, example outputs, cache, and audit trails; example handles no secrets |
| AC-30 | Final evidence report | Core regressions, Dart tests, simulator tests, and dual physical device results; releases tracked separately |

Native keystore and TLS acceptance must be demonstrated on at least one physical iOS device and one physical Android device, recording device model, OS version, plugin version, Core SHA, and key security level.

## 18. Public References & Design Notes

Public standard references:

- [Flutter: Developing packages and plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages)
- [Apple: Protecting keys with the Secure Enclave](https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave)
- [Apple: URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask)
- [Apple: URLCredential client certificate](https://developer.apple.com/documentation/foundation/urlcredential/init(identity:certificates:persistence:))
- [Android: Android Keystore system](https://developer.android.com/privacy-and-security/keystore)
- [Dart: SecurityContext.usePrivateKey](https://api.dart.dev/dart-io/SecurityContext/usePrivateKey.html)
- [RFC 7515: JSON Web Signature](https://www.rfc-editor.org/rfc/rfc7515)
- [RFC 7518: JSON Web Algorithms](https://www.rfc-editor.org/rfc/rfc7518)
