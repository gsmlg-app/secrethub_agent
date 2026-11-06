import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secrethub_agent/secrethub_agent.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registers the native iOS or Android plugin', (tester) async {
    final expectedPrefix = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android ',
      TargetPlatform.iOS => 'iOS ',
      _ => throw UnsupportedError('Run this test on iOS or Android.'),
    };
    final version = await SecretHubAgent().getPlatformVersion();
    expect(version, startsWith(expectedPrefix));
    expect(version!.length, greaterThan(expectedPrefix.length));
  });
}
