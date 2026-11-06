import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'secrethub_agent_method_channel.dart';

abstract class SecrethubAgentPlatform extends PlatformInterface {
  /// Constructs a SecrethubAgentPlatform.
  SecrethubAgentPlatform() : super(token: _token);

  static final Object _token = Object();

  static SecrethubAgentPlatform _instance = MethodChannelSecrethubAgent();

  /// The default instance of [SecrethubAgentPlatform] to use.
  ///
  /// Defaults to [MethodChannelSecrethubAgent].
  static SecrethubAgentPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SecrethubAgentPlatform] when
  /// they register themselves.
  static set instance(SecrethubAgentPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
