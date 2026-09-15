/// The category of a persisted crash.
///
/// Mirrors the `kind` discriminator written by the native plugins. [unknown]
/// covers payloads with a missing or unrecognized `kind`, for example dumps
/// from an older build.
enum NativeCrashKind {
  /// A fatal POSIX signal, for example `SIGSEGV`.
  signal,

  /// An uncaught Java / Kotlin exception on Android.
  java,

  /// An uncaught `NSException` on iOS.
  nsException,

  /// A silent death detected heuristically on the next launch (kill -9, OOM).
  abnormalTermination,

  /// Missing or unrecognized discriminator.
  unknown;

  /// Parses the raw `kind` string, tolerating case and legacy spellings.
  static NativeCrashKind fromRaw(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'signal':
        return NativeCrashKind.signal;
      case 'java':
        return NativeCrashKind.java;
      case 'nsexception':
        return NativeCrashKind.nsException;
      case 'abnormaltermination':
      // Legacy spelling used by earlier dumps.
      case 'unknown_abnormal_termination':
        return NativeCrashKind.abnormalTermination;
      default:
        return NativeCrashKind.unknown;
    }
  }
}

/// A fatal native (or JVM / NSException) crash persisted from a previous run.
class NativeCrashReport {
  /// Creates a report. Prefer [NativeCrashReport.fromMap] when parsing plugin JSON.
  const NativeCrashReport({
    required this.kind,
    required this.raw,
    this.signal,
    this.signalNumber,
    this.code,
    this.faultAddress,
    this.pid,
    this.tid,
    this.platform,
    this.arch,
    this.timestampMs,
    this.stackTrace,
    this.exceptionType,
    this.exceptionMessage,
    this.threadName,
  });

  /// Discriminator: `signal`, `java`, or `nsException`.
  final String kind;

  /// POSIX signal name when [kind] is `signal`, for example `SIGSEGV`.
  final String? signal;

  /// POSIX signal number (`si_signo`).
  final int? signalNumber;

  /// Signal code (`si_code`).
  final int? code;

  /// Faulting address as a hex string (`si_addr`).
  final String? faultAddress;

  /// Process id at crash time.
  final int? pid;

  /// Thread id at crash time.
  final int? tid;

  /// `android` or `ios`.
  final String? platform;

  /// ABI / architecture string when known.
  final String? arch;

  /// Crash time in milliseconds since epoch, UTC.
  final int? timestampMs;

  /// Best-effort native or JVM / Objective-C stack text.
  ///
  /// For `signal` crashes each native frame is resolved in-process with
  /// `dladdr` to `module!symbol + 0xoffset [0xaddress]`. C++ symbols stay
  /// mangled because demangling is not async-signal-safe; run them through
  /// `c++filt` / `ndk-stack` (Android) or symbolicate with the matching dSYM
  /// (iOS) for fully readable names. Frames that cannot be resolved fall back
  /// to the raw return address.
  final String? stackTrace;

  /// Java class name or `NSException` name when [kind] is not `signal`.
  final String? exceptionType;

  /// Exception message or reason.
  final String? exceptionMessage;

  /// JVM thread name for `java` crashes.
  final String? threadName;

  /// Original payload from native code, suitable to POST as JSON.
  final Map<String, dynamic> raw;

  /// [timestampMs] as a UTC [DateTime], if present.
  DateTime? get timestamp {
    final ms = timestampMs;
    if (ms == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// [kind] parsed into a [NativeCrashKind]. Prefer this over comparing the
  /// raw string.
  NativeCrashKind get kindType => NativeCrashKind.fromRaw(kind);

  /// Whether this report is a fatal POSIX signal.
  bool get isSignal => kindType == NativeCrashKind.signal;

  /// Whether this report is a heuristically detected silent death.
  bool get isAbnormalTermination =>
      kindType == NativeCrashKind.abnormalTermination;

  /// Whether this report is an uncaught JVM or Objective-C exception.
  bool get isException =>
      kindType == NativeCrashKind.java ||
      kindType == NativeCrashKind.nsException;

  /// A human-readable explanation of the crash.
  ///
  /// Prefers an explicit `diagnosis` from the payload (for example an
  /// `abnormalTermination` record). For a `signal` crash it derives the text
  /// from [signal]. This describes the termination mechanism, not necessarily
  /// the root cause: pair it with the stack trace, symbols and app logs.
  String get diagnosis {
    final Object? explicit = raw['diagnosis'];
    if (explicit is String && explicit.isNotEmpty) {
      return explicit;
    }
    switch (kindType) {
      case NativeCrashKind.signal:
        return _signalDiagnosis(signal);
      case NativeCrashKind.java:
      case NativeCrashKind.nsException:
        final String type = exceptionType ?? 'exception';
        final String message = exceptionMessage ?? '';
        return message.isEmpty
            ? 'Uncaught $type before the process terminated.'
            : 'Uncaught $type: $message';
      case NativeCrashKind.abnormalTermination:
        return 'The process ended without running any handler, for example '
            'kill -9 or a system OOM.';
      case NativeCrashKind.unknown:
        return 'Unclassified native diagnostic.';
    }
  }

  static String _signalDiagnosis(String? signal) {
    switch (signal) {
      case 'SIGABRT':
        return 'SIGABRT: the process was aborted intentionally, by abort(), a '
            'failed assertion or a fatal error in a native library.';
      case 'SIGSEGV':
        return 'SIGSEGV: invalid memory access.';
      case 'SIGBUS':
        return 'SIGBUS: invalid or misaligned memory access.';
      case 'SIGFPE':
        return 'SIGFPE: native arithmetic error.';
      case 'SIGILL':
        return 'SIGILL: invalid CPU instruction.';
      case 'SIGTRAP':
        return 'SIGTRAP: unhandled trap or breakpoint.';
      default:
        return 'Unidentified native signal.';
    }
  }

  /// Parses a map produced by the native plugin (or [toJson]).
  ///
  /// Tolerant of older dumps: it also accepts `snake_case` keys and a few
  /// legacy field names, so reports written by an earlier build still parse.
  factory NativeCrashReport.fromMap(Map<String, dynamic> map) {
    return NativeCrashReport(
      kind: _str(map, const ['kind']) ?? 'unknown',
      signal: _str(map, const ['signal', 'signalName', 'signal_name']),
      signalNumber: _asInt(
        _first(map, const ['signalNumber', 'signal_number']),
      ),
      code: _asInt(_first(map, const ['code'])),
      faultAddress: _str(map, const ['faultAddress', 'fault_address']),
      pid: _asInt(_first(map, const ['pid'])),
      tid: _asInt(_first(map, const ['tid'])),
      platform: _str(map, const ['platform']),
      arch: _str(map, const ['arch']),
      timestampMs: _asInt(_first(map, const ['timestampMs', 'timestamp'])),
      stackTrace: _str(map, const [
        'stackTrace',
        'symbolicated_stack_trace',
        'stack_trace',
        'raw_stack_trace',
      ]),
      exceptionType: _str(map, const ['exceptionType', 'exception_type']),
      exceptionMessage: _str(map, const ['exceptionMessage', 'message']),
      threadName: _str(map, const ['threadName', 'thread']),
      raw: Map<String, dynamic>.from(map),
    );
  }

  /// Returns a copy of [raw] for HTTP or logging.
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);

  /// Returns the first non-null value among [keys].
  static Object? _first(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final Object? value = map[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static String? _str(Map<String, dynamic> map, List<String> keys) {
    final Object? value = _first(map, keys);
    if (value == null) {
      return null;
    }
    final String text = value.toString();
    return text.isEmpty ? null : text;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  @override
  String toString() => 'NativeCrashReport($raw)';
}
