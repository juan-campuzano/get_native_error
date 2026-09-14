import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'get_native_error_platform_interface.dart';

/// An implementation of [GetNativeErrorPlatform] that uses method channels.
class MethodChannelGetNativeError extends GetNativeErrorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('get_native_error');

  @override
  Future<void> install() async {
    await methodChannel.invokeMethod<void>('install');
  }

  @override
  Future<String?> peekPendingCrash() {
    return methodChannel.invokeMethod<String>('peekPendingCrash');
  }

  @override
  Future<String?> takePendingCrash() {
    return methodChannel.invokeMethod<String>('takePendingCrash');
  }

  @override
  Future<void> crashNative() async {
    await methodChannel.invokeMethod<void>('crashNative');
  }
}
