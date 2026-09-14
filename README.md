# get_native_error

Flutter does not deliver fatal native signals (`SIGSEGV`, `SIGABRT`, and similar) to Dart. `FlutterError.onError` and `PlatformDispatcher.instance.onError` only see Dart exceptions. This plugin installs native handlers, writes a crash report to disk using async-signal-safe I/O, and hands that report to Dart **on the next launch** so your app can POST it to any API.

The isolate is not resumed. The process still dies. OOM and `SIGKILL` cannot be captured in-process.

## Install

```yaml
dependencies:
  get_native_error: ^0.0.1
```

Call `install()` as early as `main()` allows, then consume a pending report before `runApp`:

```dart
import 'package:flutter/widgets.dart';
import 'package:get_native_error/get_native_error.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeError.install();

  final crash = await NativeError.takePendingCrash();
  if (crash != null) {
    // POST crash.toJson() to your API.
  }

  runApp(const MyApp());
}
```

`takePendingCrash()` deletes the file so a report is sent once. Use `peekPendingCrash()` to inspect without deleting.

`NativeCrashReport.kind` is `signal`, `java` (Android uncaught JVM exceptions), or `nsException` (iOS uncaught `NSException`).

`NativeError.crashNative()` is **debug only**: it null-dereferences in C and kills the process. Do not call it in production.

## What is captured

| Source | Platforms |
| --- | --- |
| `SIGSEGV`, `SIGABRT`, `SIGBUS`, `SIGFPE`, `SIGILL`, `SIGTRAP` | Android, iOS |
| Uncaught Java/Kotlin exceptions | Android |
| Uncaught `NSException` | iOS |

Handlers use `SA_SIGINFO | SA_ONSTACK` and an alternate signal stack. Previous handlers (Flutter engine, Firebase Crashlytics, Sentry, and similar) are chained, then the default action is restored and the signal is re-raised so the OS still records a tombstone / crash report.

Do not install this plugin *instead of* those SDKs; install it so it can chain them. Call `NativeError.install()` after other crash reporters if you need this plugin to run first.

## Example

The example app shows a pending report after restart and a **Crash natively** button that null-dereferences in C (`SIGSEGV`). Tap it, relaunch, and the JSON payload should appear.

## Limits

- Same-session catch or recovery is impossible.
- Stack traces in the report are a best-effort frame-pointer walk. Readable symbols need `ndk-stack` (Android) or dSYMs (iOS).
- Mach exception ports, MetricKit, minidumps, and breadcrumbs are out of scope for v1.
- POSIX handlers can miss some iOS crashes that only go through Mach exceptions.

## License

MIT. See [LICENSE](LICENSE).
