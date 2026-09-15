import 'dart:convert';

import 'get_native_error_platform_interface.dart';
import 'native_crash_report.dart';

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

  /// Returns the oldest pending crash from a previous run and removes that
  /// single record so it is only reported once. Other stored crashes remain.
  static Future<NativeCrashReport?> takePendingCrash() async {
    return _parse(await GetNativeErrorPlatform.instance.takePendingCrash());
  }

  /// Returns every pending crash from previous runs, oldest first, without
  /// deleting them.
  ///
  /// A single session can produce more than one report (for example a native
  /// signal followed by a JVM exception), so prefer this over
  /// [peekPendingCrash] when you want to report all of them.
  static Future<List<NativeCrashReport>> peekPendingCrashes() async {
    return _parseAll(
      await GetNativeErrorPlatform.instance.peekPendingCrashes(),
    );
  }

  /// Returns every pending crash from previous runs, oldest first, then clears
  /// them all so they are reported once.
  static Future<List<NativeCrashReport>> takePendingCrashes() async {
    return _parseAll(
      await GetNativeErrorPlatform.instance.takePendingCrashes(),
    );
  }

  /// Removes a single stored crash by [index] (0 = oldest), keeping the rest.
  ///
  /// When processing a full list, delete from the last index down to the first
  /// so earlier indices stay valid.
  static Future<void> deletePendingCrash(int index) {
    return GetNativeErrorPlatform.instance.deletePendingCrash(index);
  }

  /// Marks the current session as a clean exit.
  ///
  /// The plugin drops a session marker on [install]. If the next launch finds
  /// that marker with no crash on disk, it reports an `abnormalTermination`
  /// (for example `kill -9` or a system OOM, which run no handler). Call this
  /// on a clean shutdown, for example from an [AppLifecycleListener], so those
  /// exits are not misreported. Detection is heuristic: mobile systems do not
  /// guarantee running code before killing a process.
  static Future<void> markHealthyExit() {
    return GetNativeErrorPlatform.instance.markHealthyExit();
  }

  /// **Debug only.** Null-dereferences in native code to raise `SIGSEGV`
  /// and kill the process. Do not call this in production.
  static Future<void> crashNative() {
    return GetNativeErrorPlatform.instance.crashNative();
  }

  /// **Debug only.** Throws an uncaught exception on a background thread so
  /// the JVM / `NSException` handler runs. Flutter would swallow the same
  /// throw on the platform thread. Do not call this in production.
  static Future<void> crashUncaughtException() {
    return GetNativeErrorPlatform.instance.crashUncaughtException();
  }

  static List<NativeCrashReport> _parseAll(List<String> lines) {
    final List<NativeCrashReport> reports = <NativeCrashReport>[];
    for (final String line in lines) {
      final NativeCrashReport? report = _parse(line);
      if (report != null) {
        reports.add(report);
      }
    }
    return reports;
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
