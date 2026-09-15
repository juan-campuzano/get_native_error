import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error/get_native_error_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelGetNativeError platform;
  const MethodChannel channel = MethodChannel('get_native_error');
  final List<MethodCall> log = <MethodCall>[];
  String? pendingJson = '{"kind":"signal","signal":"SIGABRT"}';

  setUp(() {
    platform = MethodChannelGetNativeError();
    log.clear();
    pendingJson = '{"kind":"signal","signal":"SIGABRT"}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          switch (methodCall.method) {
            case 'install':
            case 'crashNative':
              return null;
            case 'peekPendingCrash':
              return pendingJson;
            case 'takePendingCrash':
              final value = pendingJson;
              pendingJson = null;
              return value;
            case 'peekPendingCrashes':
              return pendingJson == null ? <Object?>[] : <Object?>[pendingJson];
            case 'takePendingCrashes':
              final value = pendingJson;
              pendingJson = null;
              return value == null ? <Object?>[] : <Object?>[value];
            case 'deletePendingCrash':
            case 'markHealthyExit':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('install and pending crash round-trip', () async {
    await platform.install();
    expect(await platform.peekPendingCrash(), contains('SIGABRT'));
    expect(await platform.takePendingCrash(), contains('SIGABRT'));
    expect(await platform.takePendingCrash(), isNull);
    expect(log.map((call) => call.method), [
      'install',
      'peekPendingCrash',
      'takePendingCrash',
      'takePendingCrash',
    ]);
  });

  test('pending crashes list round-trip', () async {
    expect(await platform.peekPendingCrashes(), <String>[
      '{"kind":"signal","signal":"SIGABRT"}',
    ]);
    expect(await platform.takePendingCrashes(), <String>[
      '{"kind":"signal","signal":"SIGABRT"}',
    ]);
    expect(await platform.takePendingCrashes(), isEmpty);
    await platform.deletePendingCrash(0);
    expect(log.map((call) => call.method), [
      'peekPendingCrashes',
      'takePendingCrashes',
      'takePendingCrashes',
      'deletePendingCrash',
    ]);
  });

  test('crashNative invokes the method channel', () async {
    await platform.crashNative();
    expect(log.single.method, 'crashNative');
  });

  test('peekPendingCrash returns null when native has no file', () async {
    pendingJson = null;
    expect(await platform.peekPendingCrash(), isNull);
  });
}
