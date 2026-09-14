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

  /// Parses a map produced by the native plugin (or [toJson]).
  factory NativeCrashReport.fromMap(Map<String, dynamic> map) {
    return NativeCrashReport(
      kind: map['kind'] as String? ?? 'unknown',
      signal: map['signal'] as String?,
      signalNumber: _asInt(map['signalNumber']),
      code: _asInt(map['code']),
      faultAddress: map['faultAddress'] as String?,
      pid: _asInt(map['pid']),
      tid: _asInt(map['tid']),
      platform: map['platform'] as String?,
      arch: map['arch'] as String?,
      timestampMs: _asInt(map['timestampMs']),
      stackTrace: map['stackTrace'] as String?,
      exceptionType: map['exceptionType'] as String?,
      exceptionMessage: map['exceptionMessage'] as String?,
      threadName: map['threadName'] as String?,
      raw: Map<String, dynamic>.from(map),
    );
  }

  /// Returns a copy of [raw] for HTTP or logging.
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);

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
