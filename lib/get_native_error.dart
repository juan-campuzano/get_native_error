import 'dart:convert';

import 'get_native_error_platform_interface.dart';
import 'native_crash_report.dart';

export 'native_crash_report.dart';

/// Captures fatal native signals (and JVM / NSException deaths) and returns
/// them to Dart on the **next** launch.
///
/// A signal handler cannot call Dart or HTTP. This plugin writes a crash file
/// with async-signal-safe I/O, then [takePendingCrash] reads it after restart
/// so the app can report it to any API.
class NativeError {
  NativeError._();

  /// Installs native handlers. Idempotent.
  ///
  /// The Android/iOS plugin also installs on engine attach, so this is safe
  /// to call as the first line of `main()` after
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<void> install() {
    return GetNativeErrorPlatform.instance.install();
  }

  /// Returns a pending crash from a previous run without deleting it.
  static Future<NativeCrashReport?> peekPendingCrash() async {
    return _parse(await GetNativeErrorPlatform.instance.peekPendingCrash());
  }

  /// Returns a pending crash from a previous run and deletes the file so it
  /// is only reported once.
  static Future<NativeCrashReport?> takePendingCrash() async {
    return _parse(await GetNativeErrorPlatform.instance.takePendingCrash());
  }

  /// **Debug only.** Null-dereferences in native code to raise `SIGSEGV`
  /// and kill the process. Do not call this in production.
  static Future<void> crashNative() {
    return GetNativeErrorPlatform.instance.crashNative();
  }

  static NativeCrashReport? _parse(String? json) {
    if (json == null || json.isEmpty) {
      return null;
    }
    final Object? decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) {
      return NativeCrashReport.fromMap(decoded);
    }
    if (decoded is Map) {
      return NativeCrashReport.fromMap(Map<String, dynamic>.from(decoded));
    }
    return null;
  }
}
