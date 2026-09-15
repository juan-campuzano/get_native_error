import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'get_native_error_method_channel.dart';

/// The platform interface implemented by Android and iOS.
///
/// App code should use `NativeError` instead of this class. Tests and
/// federated platform implementations may subclass it.
abstract class GetNativeErrorPlatform extends PlatformInterface {
  /// Constructs a GetNativeErrorPlatform.
  GetNativeErrorPlatform() : super(token: _token);

  static final Object _token = Object();

  static GetNativeErrorPlatform _instance = MethodChannelGetNativeError();

  /// The default instance of [GetNativeErrorPlatform] to use.
  ///
  /// Defaults to [MethodChannelGetNativeError].
  static GetNativeErrorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [GetNativeErrorPlatform] when
  /// they register themselves.
  static set instance(GetNativeErrorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Installs native crash handlers.
  Future<void> install() {
    throw UnimplementedError('install() has not been implemented.');
  }

  /// JSON for the oldest pending crash, or `null` if none. Does not delete
  /// anything.
  Future<String?> peekPendingCrash() {
    throw UnimplementedError('peekPendingCrash() has not been implemented.');
  }

  /// JSON for the oldest pending crash, or `null` if none. Removes that one
  /// record and keeps the rest.
  Future<String?> takePendingCrash() {
    throw UnimplementedError('takePendingCrash() has not been implemented.');
  }

  /// JSON for every pending crash, oldest first. Does not delete anything.
  Future<List<String>> peekPendingCrashes() {
    throw UnimplementedError('peekPendingCrashes() has not been implemented.');
  }

  /// JSON for every pending crash, oldest first, then clears them all.
  Future<List<String>> takePendingCrashes() {
    throw UnimplementedError('takePendingCrashes() has not been implemented.');
  }

  /// Removes a single stored crash by [index] (0 = oldest), keeping the rest.
  Future<void> deletePendingCrash(int index) {
    throw UnimplementedError('deletePendingCrash() has not been implemented.');
  }

  /// Marks the current session as a clean exit so the next launch does not
  /// report an abnormal termination.
  Future<void> markHealthyExit() {
    throw UnimplementedError('markHealthyExit() has not been implemented.');
  }

  /// Debug-only native crash. See `NativeError.crashNative`.
  Future<void> crashNative() {
    throw UnimplementedError('crashNative() has not been implemented.');
  }

  /// Debug-only uncaught exception. See `NativeError.crashUncaughtException`.
  Future<void> crashUncaughtException() {
    throw UnimplementedError(
      'crashUncaughtException() has not been implemented.',
    );
  }
}
