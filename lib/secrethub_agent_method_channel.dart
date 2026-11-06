import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'secrethub_agent_platform_interface.dart';

/// An implementation of [SecrethubAgentPlatform] that uses method channels.
class MethodChannelSecrethubAgent extends SecrethubAgentPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('secrethub_agent');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
