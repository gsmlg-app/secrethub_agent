import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrethub_agent_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secrethub_agent');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('shows registration separately from unimplemented SDK status', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'Android test');
    await tester.pumpWidget(const SecretHubExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('Native plugin registered: Android test'), findsOneWidget);
    expect(
      find.textContaining('The Agent SDK is not implemented yet.'),
      findsOneWidget,
    );
  });

  testWidgets('does not show native diagnostics from a platform error', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'UNAVAILABLE',
        message: 'private diagnostic',
      );
    });
    await tester.pumpWidget(const SecretHubExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('Native registration check failed.'), findsOneWidget);
    expect(find.textContaining('private diagnostic'), findsNothing);
  });

  testWidgets('handles a missing native plugin', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });
    await tester.pumpWidget(const SecretHubExampleApp());
    await tester.pumpAndSettle();
    expect(
      find.text('Native plugin unavailable on this platform.'),
      findsOneWidget,
    );
  });

  testWidgets('a null response is not successful registration', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    await tester.pumpWidget(const SecretHubExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('Native registration unavailable.'), findsOneWidget);
  });
}
