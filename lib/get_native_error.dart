/// Public API for capturing fatal native crashes and reading them on the next
/// launch.
///
/// App code should import this library only:
///
/// ```dart
/// import 'package:get_native_error/get_native_error.dart';
/// ```
library;

export 'src/native_crash_report.dart';
export 'src/native_error.dart';
export 'src/get_native_error_platform_interface.dart';
