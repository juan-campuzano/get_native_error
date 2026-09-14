import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error/get_native_error.dart';
import 'package:get_native_error/get_native_error_platform_interface.dart';
import 'package:get_native_error_example/main.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeNativeErrorPlatform
    with MockPlatformInterfaceMixin
    implements GetNativeErrorPlatform {
  int crashNativeCount = 0;

  @override
  Future<void> crashNative() async {
    crashNativeCount++;
  }

  @override
  Future<void> install() async {}

  @override
  Future<String?> peekPendingCrash() async => null;

  @override
  Future<String?> takePendingCrash() async => null;
}

void main() {
  late GetNativeErrorPlatform previous;

  setUp(() {
    previous = GetNativeErrorPlatform.instance;
  });

  tearDown(() {
    GetNativeErrorPlatform.instance = previous;
  });

  testWidgets('Shows pending crash empty state and crash button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Native crash capture'), findsOneWidget);
    expect(find.text('No pending native crash.'), findsOneWidget);
    expect(find.text('Crash natively'), findsOneWidget);
  });

  testWidgets('Shows pending crash payload from a previous launch', (
    WidgetTester tester,
  ) async {
    final crash = NativeCrashReport.fromMap({
      'kind': 'signal',
      'signal': 'SIGSEGV',
      'signalNumber': 11,
    });

    await tester.pumpWidget(MyApp(pendingCrash: crash));

    expect(find.text('No pending native crash.'), findsNothing);
    expect(find.textContaining('SIGSEGV'), findsOneWidget);
    expect(find.textContaining('signalNumber'), findsOneWidget);
  });

  testWidgets('Crash natively button calls NativeError.crashNative', (
    WidgetTester tester,
  ) async {
    final fake = _FakeNativeErrorPlatform();
    GetNativeErrorPlatform.instance = fake;

    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Crash natively'));
    await tester.pump();

    expect(fake.crashNativeCount, 1);
  });
}
