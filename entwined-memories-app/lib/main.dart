import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/app_root.dart';
import 'services/app_settings.dart';
import 'services/crash_diagnostic_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installCrashDiagnosticCapture();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final settings = await AppSettings.load();
  runApp(EntwinedMemoriesApp(settings: settings));
}

class EntwinedMemoriesApp extends StatelessWidget {
  final AppSettings settings;

  const EntwinedMemoriesApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    // Keep this inherited scope mounted while MaterialApp rebuilds for a
    // theme/language change. Android's Documents picker temporarily returns
    // control to Flutter; rebuilding the scope itself at that point can
    // deactivate an InheritedElement while Settings still depends on it.
    return AppSettingsScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => MaterialApp(
          title: 'Entwined Memories',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          home: const AppRoot(),
        ),
      ),
    );
  }

  static ThemeData get _lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB6C1),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFFE8A0B4),
          secondary: const Color(0xFFB4C9E8),
          surface: const Color(0xFFFFF8F9),
          onSurface: const Color(0xFF3D2C33),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF5F7),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3D2C33),
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Color(0xFF3D2C33)),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          color: Colors.white,
        ),
        fontFamily: 'Roboto',
      );

  static ThemeData get _darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A0B4),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF21191D),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF21191D),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFFE6ED),
          ),
          iconTheme: IconThemeData(color: Color(0xFFFFE6ED)),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          color: Color(0xFF33272C),
        ),
      );
}
