import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error/get_native_error.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('install succeeds and there is no pending crash by default', (
    WidgetTester tester,
  ) async {
    await NativeError.install();
    final pending = await NativeError.peekPendingCrash();
    expect(pending, isNull);
  });
}
