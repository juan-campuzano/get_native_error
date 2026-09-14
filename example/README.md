# get_native_error_example

Demonstrates next-launch native crash capture.

1. Run the app.
2. Tap **Crash natively** (the process will die).
3. Open the app again. The previous SIGSEGV payload is shown so you can POST `crash.toJson()` to your API.
