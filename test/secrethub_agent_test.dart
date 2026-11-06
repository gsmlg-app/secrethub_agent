import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:secrethub_agent/secrethub_agent.dart';
import 'package:secrethub_agent/secrethub_agent_method_channel.dart';
import 'package:secrethub_agent/secrethub_agent_platform_interface.dart';

class FakeSecrethubAgentPlatform
    with MockPlatformInterfaceMixin
    implements SecrethubAgentPlatform {
  @override
  Future<String?> getPlatformVersion() async => 'Android test';
}

void main() {
  final initialPlatform = SecrethubAgentPlatform.instance;

  tearDown(() => SecrethubAgentPlatform.instance = initialPlatform);

  test('uses the native method channel by default', () {
    expect(initialPlatform, isA<MethodChannelSecrethubAgent>());
  });

  test(
    'the public diagnostic delegates to the platform implementation',
    () async {
      SecrethubAgentPlatform.instance = FakeSecrethubAgentPlatform();
      expect(await SecretHubAgent().getPlatformVersion(), 'Android test');
    },
  );
}
