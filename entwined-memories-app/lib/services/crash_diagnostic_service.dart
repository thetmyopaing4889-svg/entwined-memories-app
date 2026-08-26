import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Captures framework errors locally so a device-only lifecycle failure can be
/// investigated without collecting archive contents, credentials, or secrets.
/// The native side keeps only the latest sanitized record in private app storage.
class CrashDiagnosticService {
  static const MethodChannel _channel =
      MethodChannel('entwined_memories/crash_diagnostics');

  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    final exception = details.exceptionAsString();
    // This temporary diagnostic path is intentionally limited to the exact
    // framework assertion under investigation, never general user data/errors.
    if (!exception.contains('_dependents.isEmpty')) return;
    await _record(
      kind: 'flutter_framework_error',
      exception: exception,
      stack: details.stack?.toString() ?? StackTrace.current.toString(),
      context: details.context?.toDescription() ?? '',
      library: details.library ?? '',
    );
  }

  static Future<void> recordUnhandledError(Object error, StackTrace stack) {
    return _record(
      kind: 'dart_unhandled_error',
      exception: error.toString(),
      stack: stack.toString(),
      context: '',
      library: '',
    );
  }

  static Future<void> _record({
    required String kind,
    required String exception,
    required String stack,
    required String context,
    required String library,
  }) async {
    try {
      await _channel.invokeMethod<void>('recordFlutterDiagnostic', {
        'kind': kind,
        'exception': exception,
        'stack': stack,
        'context': context,
        'library': library,
        'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
      });
    } on PlatformException {
      // Error reporting must never replace the original framework error.
    } on MissingPluginException {
      // Allows widget tests and non-Android targets to run without the bridge.
    }
  }

  static Future<String?> readLatest() async {
    try {
      final value = await _channel.invokeMethod<String>('readLatestFlutterDiagnostic');
      return value?.trim().isEmpty ?? true ? null : value;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// Registers one non-invasive reporter before the widget tree is created.
/// Flutter still displays its normal debug error screen; this only persists the
/// technical stack required to diagnose a device-specific failure afterwards.
void installCrashDiagnosticCapture() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(CrashDiagnosticService.recordFlutterError(details));
  };
}
