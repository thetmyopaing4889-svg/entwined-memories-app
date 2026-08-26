import 'package:entwined_memories/services/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'settings scope remains mounted while the MaterialApp subtree rebuilds',
      (tester) async {
    final settings = AppSettings();

    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: AnimatedBuilder(
          animation: settings,
          builder: (context, _) => MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Text(
                  AppSettingsScope.of(context).language.name,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('myanmar'), findsOneWidget);

    // This mirrors a rebuild that can happen after returning from an Android
    // system picker. The scope must remain mounted for its dependent subtree.
    settings.notifyListeners();
    await tester.pump();

    expect(find.text('myanmar'), findsOneWidget);
  });
}
