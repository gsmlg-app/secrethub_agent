import 'secrethub_agent_platform_interface.dart';

/// Native registration diagnostics for the SecretHub Agent plugin bootstrap.
///
/// Enrollment, secret reads, offline storage, and the runtime API in DESIGN.md
/// are not implemented. This diagnostic does not check key protection or Core
/// compatibility.
class SecretHubAgent {
  /// Returns the host OS version through the registered native plugin.
  ///
  /// A successful response proves only that the platform channel is registered.
  Future<String?> getPlatformVersion() {
    return SecrethubAgentPlatform.instance.getPlatformVersion();
  }
}
