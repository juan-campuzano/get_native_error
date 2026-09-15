import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error/get_native_error.dart';
import 'package:get_native_error/get_native_error_method_channel.dart';
import 'package:get_native_error/get_native_error_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGetNativeErrorPlatform
    with MockPlatformInterfaceMixin
    implements GetNativeErrorPlatform {
  String? pending;
  List<String> pendingList = <String>[];
  int installCount = 0;
  int crashNativeCount = 0;
  int healthyExitCount = 0;
  final List<int> deletedIndices = <int>[];

  @override
  Future<void> install() async {
    installCount++;
  }

  @override
  Future<String?> peekPendingCrash() async => pending;

  @override
  Future<String?> takePendingCrash() async {
    final value = pending;
    pending = null;
    return value;
  }

  @override
  Future<List<String>> peekPendingCrashes() async =>
      List<String>.from(pendingList);

  @override
  Future<List<String>> takePendingCrashes() async {
    final value = List<String>.from(pendingList);
    pendingList = <String>[];
    return value;
  }

  @override
  Future<void> deletePendingCrash(int index) async {
    deletedIndices.add(index);
    if (index >= 0 && index < pendingList.length) {
      pendingList.removeAt(index);
    }
  }

  @override
  Future<void> markHealthyExit() async {
    healthyExitCount++;
  }

  @override
  Future<void> crashNative() async {
    crashNativeCount++;
  }
}

void main() {
  late GetNativeErrorPlatform initialPlatform;

  setUp(() {
    initialPlatform = GetNativeErrorPlatform.instance;
  });

  tearDown(() {
    GetNativeErrorPlatform.instance = initialPlatform;
  });

  test('$MethodChannelGetNativeError is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGetNativeError>());
  });

  test('install and crashNative delegate to the platform', () async {
    final fakePlatform = MockGetNativeErrorPlatform();
    GetNativeErrorPlatform.instance = fakePlatform;

    await NativeError.install();
    await NativeError.crashNative();

    expect(fakePlatform.installCount, 1);
    expect(fakePlatform.crashNativeCount, 1);
  });

  test('peekPendingCrash does not consume the pending report', () async {
    final fakePlatform = MockGetNativeErrorPlatform()
      ..pending = '{"kind":"signal","signal":"SIGBUS"}';
    GetNativeErrorPlatform.instance = fakePlatform;

    final first = await NativeError.peekPendingCrash();
    final second = await NativeError.peekPendingCrash();

    expect(first?.signal, 'SIGBUS');
    expect(second?.signal, 'SIGBUS');
    expect(await NativeError.takePendingCrash(), isNotNull);
  });

  test('takePendingCrash parses JSON and clears the pending file', () async {
    final fakePlatform = MockGetNativeErrorPlatform()
      ..pending =
          '{"kind":"signal","signal":"SIGSEGV","signalNumber":11,"timestampMs":1}';
    GetNativeErrorPlatform.instance = fakePlatform;

    await NativeError.install();
    final peeked = await NativeError.peekPendingCrash();
    expect(peeked?.signal, 'SIGSEGV');

    final taken = await NativeError.takePendingCrash();
    expect(taken?.kind, 'signal');
    expect(taken?.signalNumber, 11);
    expect(await NativeError.takePendingCrash(), isNull);
  });

  test('peekPendingCrashes parses every record without consuming', () async {
    final fakePlatform = MockGetNativeErrorPlatform()
      ..pendingList = <String>[
        '{"kind":"signal","signal":"SIGSEGV"}',
        '{"kind":"java","exceptionType":"java.lang.RuntimeException"}',
      ];
    GetNativeErrorPlatform.instance = fakePlatform;

    final reports = await NativeError.peekPendingCrashes();
    expect(reports, hasLength(2));
    expect(reports.first.signal, 'SIGSEGV');
    expect(reports.last.exceptionType, 'java.lang.RuntimeException');
    expect(await NativeError.peekPendingCrashes(), hasLength(2));
  });

  test('takePendingCrashes parses and clears all records', () async {
    final fakePlatform = MockGetNativeErrorPlatform()
      ..pendingList = <String>['{"kind":"signal","signal":"SIGABRT"}'];
    GetNativeErrorPlatform.instance = fakePlatform;

    final reports = await NativeError.takePendingCrashes();
    expect(reports, hasLength(1));
    expect(reports.single.signal, 'SIGABRT');
    expect(await NativeError.takePendingCrashes(), isEmpty);
  });

  test('deletePendingCrash delegates the index to the platform', () async {
    final fakePlatform = MockGetNativeErrorPlatform()
      ..pendingList = <String>['{"kind":"signal"}', '{"kind":"java"}'];
    GetNativeErrorPlatform.instance = fakePlatform;

    await NativeError.deletePendingCrash(1);
    expect(fakePlatform.deletedIndices, <int>[1]);
    expect(fakePlatform.pendingList, hasLength(1));
  });

  test('markHealthyExit delegates to the platform', () async {
    final fakePlatform = MockGetNativeErrorPlatform();
    GetNativeErrorPlatform.instance = fakePlatform;

    await NativeError.markHealthyExit();
    expect(fakePlatform.healthyExitCount, 1);
  });

  test('parses an abnormalTermination record from a previous run', () async {
    final fakePlatform = MockGetNativeErrorPlatform()
      ..pending =
          '{"kind":"abnormalTermination","diagnosis":"system OOM","platform":"android"}';
    GetNativeErrorPlatform.instance = fakePlatform;

    final report = await NativeError.takePendingCrash();
    expect(report?.kind, 'abnormalTermination');
    expect(report?.platform, 'android');
    expect(report?.raw['diagnosis'], 'system OOM');
  });

  test('parses java JSON from a previous run', () async {
    final fakePlatform = MockGetNativeErrorPlatform()
      ..pending =
          '{"kind":"java","exceptionType":"java.lang.RuntimeException","threadName":"main"}';
    GetNativeErrorPlatform.instance = fakePlatform;

    final report = await NativeError.takePendingCrash();
    expect(report?.kind, 'java');
    expect(report?.exceptionType, 'java.lang.RuntimeException');
    expect(report?.threadName, 'main');
  });

  test('returns null when there is no pending JSON', () async {
    GetNativeErrorPlatform.instance = MockGetNativeErrorPlatform();

    expect(await NativeError.peekPendingCrash(), isNull);
    expect(await NativeError.takePendingCrash(), isNull);
  });

  test('returns null for empty pending JSON', () async {
    GetNativeErrorPlatform.instance = MockGetNativeErrorPlatform()
      ..pending = '';

    expect(await NativeError.peekPendingCrash(), isNull);
  });

  test('returns null when pending JSON is not an object', () async {
    GetNativeErrorPlatform.instance = MockGetNativeErrorPlatform()
      ..pending = '["signal"]';

    expect(await NativeError.takePendingCrash(), isNull);
  });

  test('throws FormatException for invalid pending JSON', () async {
    GetNativeErrorPlatform.instance = MockGetNativeErrorPlatform()
      ..pending = '{not-json';

    expect(NativeError.peekPendingCrash(), throwsFormatException);
  });
}
