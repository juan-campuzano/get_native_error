# get_native_error

Flutter does not deliver fatal native signals (`SIGSEGV`, `SIGABRT`, and similar) to Dart. `FlutterError.onError` and `PlatformDispatcher.instance.onError` only see Dart exceptions. This plugin installs native handlers, writes a crash report to disk using async-signal-safe I/O, and hands that report to Dart **on the next launch** so your app can POST it to any API.

The isolate is not resumed. The process still dies. OOM and `SIGKILL` cannot be captured in-process.

## Install

```yaml
dependencies:
  get_native_error: ^0.0.1
```

Call `install()` as early as `main()` allows, then consume pending reports before `runApp`:

```dart
import 'package:flutter/widgets.dart';
import 'package:get_native_error/get_native_error.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeError.install();

  final crashes = await NativeError.takePendingCrashes();
  for (final crash in crashes) {
    // POST crash.toJson() to your API, or log crash.summary for triage.
  }

  runApp(const MyApp());
}
```

A single session can leave more than one report (for example a native signal followed by a JVM exception), so reports are stored as JSON Lines and read as a list.

### Reading reports

- `takePendingCrashes()` returns every report, oldest first, then clears them all.
- `peekPendingCrashes()` returns every report without deleting them.
- `takePendingCrash()` / `peekPendingCrash()` operate on the oldest single report. `takePendingCrash()` removes only that one and keeps the rest.
- `deletePendingCrash(index)` removes one stored report by index (0 = oldest). When processing a full list, delete from the last index down to the first so earlier indices stay valid.

### The report

`NativeCrashReport.kindType` is a typed `NativeCrashKind`:

| Kind | Meaning |
| --- | --- |
| `signal` | Fatal POSIX signal |
| `java` | Android uncaught JVM exception |
| `nsException` | iOS uncaught `NSException` |
| `abnormalTermination` | Silent death detected on the next launch (kill -9, system OOM) |
| `unknown` | Missing or unrecognized discriminator (for example a legacy dump) |

Convenience flags `isSignal`, `isException` and `isAbnormalTermination` are available. `diagnosis` explains the termination mechanism. `crashSite` is the first stack frame (the place to inspect for a hotfix). `summary` is a one-line combination of those plus the fault address, suitable to log or POST. `raw` / `toJson()` keep the original payload. `fromMap` is tolerant of older dumps, accepting `snake_case` and a few legacy field names.

### Clean exits

The plugin drops a session marker on `install()`. If the next launch finds that marker with no crash on disk, it reports an `abnormalTermination`. Call `markHealthyExit()` on a clean shutdown so those exits are not misreported:

```dart
final listener = AppLifecycleListener(
  onDetach: () => NativeError.markHealthyExit(),
);
```

Detection is heuristic: mobile systems do not guarantee running code before killing a process.

`NativeError.crashNative()` is **debug only**: it null-dereferences in C and kills the process. `NativeError.crashUncaughtException()` throws on a **background** thread so the JVM / `NSException` handler runs (the same throw on the platform thread would be swallowed by Flutter). Do not call either in production.

## What is captured

| Source | Platforms |
| --- | --- |
| `SIGSEGV`, `SIGABRT`, `SIGBUS`, `SIGFPE`, `SIGILL`, `SIGTRAP` | Android, iOS |
| Uncaught Java/Kotlin exceptions | Android |
| Uncaught `NSException` | iOS |
| Abnormal termination (kill -9, system OOM), heuristically | Android, iOS |

Handlers use `SA_SIGINFO | SA_ONSTACK` and an alternate signal stack. Previous handlers (Flutter engine, Firebase Crashlytics, Sentry, and similar) are chained, then the default action is restored and the signal is re-raised so the OS still records a tombstone / crash report.

Do not install this plugin *instead of* those SDKs; install it so it can chain them. Call `NativeError.install()` after other crash reporters if you need this plugin to run first.

## Symbolication

Native `signal` frames start at the faulting PC from `ucontext` (not the signal handler). Each address is resolved in-process with `dladdr`:

- `libfoo.so!function + 0x12 [0xaddress]` when a symbol is mapped
- `libfoo.so + 0x1a4c [0xaddress]` when the library is stripped (`0x1a4c` is the offset from the module base, which `ndk-stack` / a dSYM can still resolve)

Module names are basenames, so Android APK paths do not hide the `.so`. C++ names stay mangled because demangling is not async-signal-safe. For production analysis, keep the build symbols: unstripped `.so` / NDK symbols on Android, and the dSYM for the same build on iOS.

## Example

The example app lists pending reports after restart (title, `diagnosis`, crash site, expandable stack), lets you copy a one-line `summary`, delete reports individually, wires `markHealthyExit()` to the app lifecycle, and has debug buttons for a native `SIGSEGV` and an uncaught JVM / `NSException`. Tap one, relaunch, and the reports should appear.

## Limits

- Same-session catch or recovery is impossible.
- Stack traces in the report are a best-effort unwind from the faulting PC plus a frame-pointer walk, resolved in-process. Fully readable C++ symbols still need `ndk-stack` / `c++filt` (Android) or dSYMs (iOS).
- Abnormal-termination detection is heuristic and depends on `markHealthyExit()` being called on clean exits.
- Mach exception ports, MetricKit, minidumps, and breadcrumbs are out of scope for v1.
- POSIX handlers can miss some iOS crashes that only go through Mach exceptions.

## License

MIT. See [LICENSE](LICENSE).
