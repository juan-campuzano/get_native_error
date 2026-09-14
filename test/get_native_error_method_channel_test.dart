import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error/get_native_error_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelGetNativeError platform = MethodChannelGetNativeError();
  const MethodChannel channel = MethodChannel('get_native_error');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'install':
            case 'crashNative':
              return null;
            case 'peekPendingCrash':
            case 'takePendingCrash':
              return '{"kind":"signal","signal":"SIGABRT"}';
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
  });
}
