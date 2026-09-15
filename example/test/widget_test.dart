import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error/get_native_error.dart';
import 'package:get_native_error/get_native_error_platform_interface.dart';
import 'package:get_native_error_example/main.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeNativeErrorPlatform
    with MockPlatformInterfaceMixin
    implements GetNativeErrorPlatform {
  int crashNativeCount = 0;
  final List<int> deletedIndices = <int>[];

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

  @override
  Future<List<String>> peekPendingCrashes() async => const <String>[];

  @override
  Future<List<String>> takePendingCrashes() async => const <String>[];

  @override
  Future<void> deletePendingCrash(int index) async {
    deletedIndices.add(index);
  }

  @override
  Future<void> markHealthyExit() async {}
}

void main() {
  late GetNativeErrorPlatform previous;

  setUp(() {
    previous = GetNativeErrorPlatform.instance;
  });

  tearDown(() {
    GetNativeErrorPlatform.instance = previous;
  });

  testWidgets('Shows empty state and crash button', (
    WidgetTester tester,
  ) async {
    GetNativeErrorPlatform.instance = _FakeNativeErrorPlatform();

    await tester.pumpWidget(const MyApp());

    expect(find.text('Native crash capture'), findsOneWidget);
    expect(find.text('No pending reports.'), findsOneWidget);
    expect(find.text('Crash natively (SIGSEGV)'), findsOneWidget);
  });

  testWidgets('Shows pending reports from previous launches', (
    WidgetTester tester,
  ) async {
    GetNativeErrorPlatform.instance = _FakeNativeErrorPlatform();

    final crashes = <NativeCrashReport>[
      NativeCrashReport.fromMap({
        'kind': 'signal',
        'signal': 'SIGSEGV',
        'signalNumber': 11,
      }),
      NativeCrashReport.fromMap({
        'kind': 'abnormalTermination',
        'diagnosis': 'system OOM',
      }),
    ];

    await tester.pumpWidget(MyApp(pendingCrashes: crashes));

    expect(find.text('No pending reports.'), findsNothing);
    expect(find.text('2 pending report(s):'), findsOneWidget);
    expect(find.text('SIGSEGV'), findsOneWidget);
    expect(find.text('Abnormal termination'), findsOneWidget);
  });

  testWidgets('Crash button calls NativeError.crashNative', (
    WidgetTester tester,
  ) async {
    final fake = _FakeNativeErrorPlatform();
    GetNativeErrorPlatform.instance = fake;

    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Crash natively (SIGSEGV)'));
    await tester.pump();

    expect(fake.crashNativeCount, 1);
  });

  testWidgets('Delete button removes a report by index', (
    WidgetTester tester,
  ) async {
    final fake = _FakeNativeErrorPlatform();
    GetNativeErrorPlatform.instance = fake;

    final crashes = <NativeCrashReport>[
      NativeCrashReport.fromMap({'kind': 'signal', 'signal': 'SIGABRT'}),
    ];

    await tester.pumpWidget(MyApp(pendingCrashes: crashes));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(fake.deletedIndices, <int>[0]);
  });
}
