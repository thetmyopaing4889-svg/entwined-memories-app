import 'package:entwined_memories/services/crash_diagnostic_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('entwined_memories/crash_diagnostics');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('records only the target inherited-widget assertion', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });

    await CrashDiagnosticService.recordFlutterError(
      FlutterErrorDetails(
        exception: FlutterError('_dependents.isEmpty: is not true'),
        stack: StackTrace.fromString('#0 framework.dart:6179'),
        library: 'widgets library',
      ),
    );

    expect(captured?.method, 'recordFlutterDiagnostic');
    final arguments = captured?.arguments as Map<dynamic, dynamic>;
    expect(arguments['exception'], contains('_dependents.isEmpty'));
    expect(arguments['stack'], contains('framework.dart:6179'));
  });

  test('does not send unrelated Flutter errors to diagnostic storage', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls++;
      return true;
    });

    await CrashDiagnosticService.recordFlutterError(
      FlutterErrorDetails(
        exception: FlutterError('ordinary layout error'),
        stack: StackTrace.current,
      ),
    );

    expect(calls, 0);
  });
}
