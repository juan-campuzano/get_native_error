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
}
