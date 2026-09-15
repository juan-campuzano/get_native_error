## 0.0.2-rc.1

* Persist multiple reports per session as JSON Lines. Added `takePendingCrashes()` / `peekPendingCrashes()` (list) and `deletePendingCrash(index)`; `takePendingCrash()` now removes only the oldest record and keeps the rest.
* Resolve native `signal` frames in-process with `dladdr` (`module!symbol + 0xoffset [0xaddress]`); C++ demangling is left to `c++filt` / `ndk-stack` / dSYM so the signal handler stays async-signal-safe.
* Detect abnormal terminations that run no handler (kill -9, system OOM) via a session marker. New `abnormalTermination` report kind and `markHealthyExit()` to mark clean exits.
* Typed `NativeCrashKind` with `kindType`, `isSignal`, `isException`, `isAbnormalTermination`, and a `diagnosis` getter. `fromMap` now tolerates `snake_case` and legacy field names.

## 0.0.1

* Initial Android and iOS plugin that persists fatal native signals (and JVM / NSException deaths) and returns them to Dart on the next launch.
