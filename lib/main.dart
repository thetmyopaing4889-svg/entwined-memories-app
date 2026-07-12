import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/app_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const EntwinedMemoriesApp());
}

class EntwinedMemoriesApp extends StatelessWidget {
  const EntwinedMemoriesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entwined Memories',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
        cardTheme: const CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          color: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const AppRoot(),
    );
  }
}
