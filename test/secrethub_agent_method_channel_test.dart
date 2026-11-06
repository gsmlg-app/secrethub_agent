import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrethub_agent/secrethub_agent_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelSecrethubAgent();
  const channel = MethodChannel('secrethub_agent');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends only the registration diagnostic with no arguments', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'iOS test';
    });
    expect(await platform.getPlatformVersion(), 'iOS test');
    expect(calls, hasLength(1));
    expect(calls.single.method, 'getPlatformVersion');
    expect(calls.single.arguments, isNull);
  });

  test('does not turn a native failure into successful registration', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });
    await expectLater(
      platform.getPlatformVersion(),
      throwsA(isA<PlatformException>()),
    );
  });

  test('does not report registration when no native plugin exists', () async {
    await expectLater(
      platform.getPlatformVersion(),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
