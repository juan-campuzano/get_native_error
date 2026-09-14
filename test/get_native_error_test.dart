import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error/get_native_error.dart';
import 'package:get_native_error/get_native_error_method_channel.dart';
import 'package:get_native_error/get_native_error_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGetNativeErrorPlatform
    with MockPlatformInterfaceMixin
    implements GetNativeErrorPlatform {
  String? pending;

  @override
  Future<void> install() async {}

  @override
  Future<String?> peekPendingCrash() async => pending;

  @override
  Future<String?> takePendingCrash() async {
    final value = pending;
    pending = null;
    return value;
  }

  @override
  Future<void> crashNative() async {}
}

void main() {
  final GetNativeErrorPlatform initialPlatform =
      GetNativeErrorPlatform.instance;

  test('$MethodChannelGetNativeError is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGetNativeError>());
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

  test('fromMap copies extras into raw for API posting', () {
    final report = NativeCrashReport.fromMap({
      'kind': 'java',
      'exceptionType': 'java.lang.RuntimeException',
      'custom': 'field',
    });
    expect(report.exceptionType, 'java.lang.RuntimeException');
    expect(report.toJson()['custom'], 'field');
  });
}
