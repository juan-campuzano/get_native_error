import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error/get_native_error_platform_interface.dart';

class UnimplementedGetNativeErrorPlatform extends GetNativeErrorPlatform {}

class InvalidTokenPlatform implements GetNativeErrorPlatform {
  @override
  Future<void> crashNative() async {}

  @override
  Future<void> install() async {}

  @override
  Future<String?> peekPendingCrash() async => null;

  @override
  Future<String?> takePendingCrash() async => null;
}

void main() {
  test('unimplemented methods throw UnimplementedError', () {
    final platform = UnimplementedGetNativeErrorPlatform();

    expect(platform.install, throwsUnimplementedError);
    expect(platform.peekPendingCrash, throwsUnimplementedError);
    expect(platform.takePendingCrash, throwsUnimplementedError);
    expect(platform.crashNative, throwsUnimplementedError);
  });

  test('rejects instances that do not extend GetNativeErrorPlatform', () {
    expect(
      () => GetNativeErrorPlatform.instance = InvalidTokenPlatform(),
      throwsA(isA<AssertionError>()),
    );
  });
}
