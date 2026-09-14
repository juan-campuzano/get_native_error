import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error_example/main.dart';

void main() {
  testWidgets('Shows pending crash empty state and crash button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('No pending native crash.'), findsOneWidget);
    expect(find.text('Crash natively'), findsOneWidget);
  });
}
