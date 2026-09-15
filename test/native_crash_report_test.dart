import 'package:flutter_test/flutter_test.dart';
import 'package:get_native_error/native_crash_report.dart';

void main() {
  group('NativeCrashReport.fromMap', () {
    test('parses a full signal payload', () {
      final report = NativeCrashReport.fromMap({
        'kind': 'signal',
        'signal': 'SIGSEGV',
        'signalNumber': 11,
        'code': 1,
        'faultAddress': '0x0',
        'pid': 42,
        'tid': 7,
        'platform': 'android',
        'arch': 'arm64-v8a',
        'timestampMs': 1_700_000_000_000,
        'stackTrace': '#0 pc 0x10',
      });

      expect(report.kind, 'signal');
      expect(report.signal, 'SIGSEGV');
      expect(report.signalNumber, 11);
      expect(report.code, 1);
      expect(report.faultAddress, '0x0');
      expect(report.pid, 42);
      expect(report.tid, 7);
      expect(report.platform, 'android');
      expect(report.arch, 'arm64-v8a');
      expect(report.timestampMs, 1_700_000_000_000);
      expect(report.stackTrace, '#0 pc 0x10');
      expect(report.exceptionType, isNull);
      expect(report.exceptionMessage, isNull);
      expect(report.threadName, isNull);
    });

    test('parses a java crash', () {
      final report = NativeCrashReport.fromMap({
        'kind': 'java',
        'exceptionType': 'java.lang.IllegalStateException',
        'exceptionMessage': 'boom',
        'threadName': 'main',
        'platform': 'android',
        'stackTrace': 'java.lang.IllegalStateException: boom',
      });

      expect(report.kind, 'java');
      expect(report.exceptionType, 'java.lang.IllegalStateException');
      expect(report.exceptionMessage, 'boom');
      expect(report.threadName, 'main');
      expect(report.signal, isNull);
    });

    test('parses an nsException crash', () {
      final report = NativeCrashReport.fromMap({
        'kind': 'nsException',
        'exceptionType': 'NSInvalidArgumentException',
        'exceptionMessage': 'unrecognized selector',
        'platform': 'ios',
      });

      expect(report.kind, 'nsException');
      expect(report.exceptionType, 'NSInvalidArgumentException');
      expect(report.platform, 'ios');
    });

    test('defaults kind to unknown when missing', () {
      final report = NativeCrashReport.fromMap({'signal': 'SIGABRT'});
      expect(report.kind, 'unknown');
    });

    test('coerces numeric fields from num and string', () {
      final report = NativeCrashReport.fromMap({
        'kind': 'signal',
        'signalNumber': 11.0,
        'code': '2',
        'pid': 3.9,
        'tid': 'not-a-number',
        'timestampMs': true,
      });

      expect(report.signalNumber, 11);
      expect(report.code, 2);
      expect(report.pid, 3);
      expect(report.tid, isNull);
      expect(report.timestampMs, isNull);
    });

    test('copies extras into raw and toJson', () {
      final source = <String, dynamic>{
        'kind': 'java',
        'exceptionType': 'java.lang.RuntimeException',
        'custom': 'field',
      };
      final report = NativeCrashReport.fromMap(source);

      expect(report.toJson()['custom'], 'field');
      expect(report.raw, isNot(same(source)));
      expect(report.toJson(), isNot(same(report.raw)));

      final json = report.toJson();
      json['custom'] = 'mutated';
      expect(report.raw['custom'], 'field');
      expect(report.toJson()['custom'], 'field');
    });
  });

  group('NativeCrashReport.timestamp', () {
    test('converts timestampMs to UTC DateTime', () {
      final report = NativeCrashReport.fromMap({
        'kind': 'signal',
        'timestampMs': 1_000,
      });
      expect(report.timestamp, DateTime.utc(1970, 1, 1, 0, 0, 1));
    });

    test('is null when timestampMs is absent', () {
      final report = NativeCrashReport.fromMap({'kind': 'signal'});
      expect(report.timestamp, isNull);
    });
  });

  test('toString includes the raw payload', () {
    final report = NativeCrashReport.fromMap({
      'kind': 'signal',
      'signal': 'SIGTRAP',
    });
    expect(report.toString(), contains('SIGTRAP'));
    expect(report.toString(), startsWith('NativeCrashReport('));
  });

  group('NativeCrashReport.kindType', () {
    test('maps known kinds', () {
      expect(
        NativeCrashReport.fromMap({'kind': 'signal'}).kindType,
        NativeCrashKind.signal,
      );
      expect(
        NativeCrashReport.fromMap({'kind': 'java'}).kindType,
        NativeCrashKind.java,
      );
      expect(
        NativeCrashReport.fromMap({'kind': 'nsException'}).kindType,
        NativeCrashKind.nsException,
      );
      expect(
        NativeCrashReport.fromMap({'kind': 'abnormalTermination'}).kindType,
        NativeCrashKind.abnormalTermination,
      );
    });

    test('accepts the legacy abnormal-termination spelling', () {
      expect(
        NativeCrashReport.fromMap({
          'kind': 'UNKNOWN_ABNORMAL_TERMINATION',
        }).kindType,
        NativeCrashKind.abnormalTermination,
      );
    });

    test('falls back to unknown for missing or unrecognized kinds', () {
      expect(NativeCrashReport.fromMap({}).kindType, NativeCrashKind.unknown);
      expect(
        NativeCrashReport.fromMap({'kind': 'weird'}).kindType,
        NativeCrashKind.unknown,
      );
    });

    test('convenience flags reflect the kind', () {
      final signal = NativeCrashReport.fromMap({'kind': 'signal'});
      expect(signal.isSignal, isTrue);
      expect(signal.isException, isFalse);
      expect(signal.isAbnormalTermination, isFalse);

      final java = NativeCrashReport.fromMap({'kind': 'java'});
      expect(java.isException, isTrue);

      final abnormal = NativeCrashReport.fromMap({
        'kind': 'abnormalTermination',
      });
      expect(abnormal.isAbnormalTermination, isTrue);
    });
  });

  group('NativeCrashReport legacy fields', () {
    test('parses snake_case and legacy field names', () {
      final report = NativeCrashReport.fromMap({
        'signal_name': 'SIGSEGV',
        'signal_number': 11,
        'stack_trace': '#0 legacy',
        'exception_type': 'java.lang.RuntimeException',
        'message': 'legacy message',
        'thread': 'main',
        'device_info': {'model': 'Pixel'},
      });

      // No 'kind' present in the legacy dump.
      expect(report.kindType, NativeCrashKind.unknown);
      expect(report.signal, 'SIGSEGV');
      expect(report.signalNumber, 11);
      expect(report.stackTrace, '#0 legacy');
      expect(report.exceptionType, 'java.lang.RuntimeException');
      expect(report.exceptionMessage, 'legacy message');
      expect(report.threadName, 'main');
      // Unknown fields survive in raw for POSTing.
      expect(report.raw['device_info'], isA<Map>());
    });

    test('prefers current field names over legacy ones', () {
      final report = NativeCrashReport.fromMap({
        'signal': 'SIGABRT',
        'signal_name': 'SIGSEGV',
        'stackTrace': '#0 current',
        'stack_trace': '#0 legacy',
      });
      expect(report.signal, 'SIGABRT');
      expect(report.stackTrace, '#0 current');
    });
  });

  group('NativeCrashReport.diagnosis', () {
    test('derives text from the signal name', () {
      expect(
        NativeCrashReport.fromMap({
          'kind': 'signal',
          'signal': 'SIGSEGV',
        }).diagnosis,
        contains('invalid memory access'),
      );
      expect(
        NativeCrashReport.fromMap({
          'kind': 'signal',
          'signal': 'SIGABRT',
        }).diagnosis,
        startsWith('SIGABRT'),
      );
    });

    test('falls back for an unknown signal', () {
      expect(
        NativeCrashReport.fromMap({
          'kind': 'signal',
          'signal': 'SIGWAT',
        }).diagnosis,
        'Unidentified native signal.',
      );
    });

    test('prefers an explicit diagnosis from the payload', () {
      final report = NativeCrashReport.fromMap({
        'kind': 'abnormalTermination',
        'diagnosis': 'system OOM',
      });
      expect(report.diagnosis, 'system OOM');
    });

    test('summarizes java and nsException crashes', () {
      final java = NativeCrashReport.fromMap({
        'kind': 'java',
        'exceptionType': 'java.lang.IllegalStateException',
        'exceptionMessage': 'boom',
      });
      expect(java.diagnosis, contains('IllegalStateException'));
      expect(java.diagnosis, contains('boom'));

      final ns = NativeCrashReport.fromMap({
        'kind': 'nsException',
        'exceptionType': 'NSInvalidArgumentException',
      });
      expect(ns.diagnosis, contains('NSInvalidArgumentException'));
    });
  });
}
