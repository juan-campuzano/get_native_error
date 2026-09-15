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
  Future<List<String>> peekPendingCrashes() async {
    final List<Object?>? result = await methodChannel
        .invokeMethod<List<Object?>>('peekPendingCrashes');
    return _asStringList(result);
  }

  @override
  Future<List<String>> takePendingCrashes() async {
    final List<Object?>? result = await methodChannel
        .invokeMethod<List<Object?>>('takePendingCrashes');
    return _asStringList(result);
  }

  @override
  Future<void> deletePendingCrash(int index) async {
    await methodChannel.invokeMethod<void>('deletePendingCrash', index);
  }

  @override
  Future<void> markHealthyExit() async {
    await methodChannel.invokeMethod<void>('markHealthyExit');
  }

  @override
  Future<void> crashNative() async {
    await methodChannel.invokeMethod<void>('crashNative');
  }

  @override
  Future<void> crashUncaughtException() async {
    await methodChannel.invokeMethod<void>('crashUncaughtException');
  }

  List<String> _asStringList(List<Object?>? result) {
    if (result == null) {
      return const <String>[];
    }
    return result
        .whereType<Object>()
        .map((Object item) => item.toString())
        .toList(growable: false);
  }
}
