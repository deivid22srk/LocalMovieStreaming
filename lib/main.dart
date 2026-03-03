import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'providers/movie_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/initial_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isFirstRun = prefs.getBool('is_first_run') ?? true;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MovieProvider()),
      ],
      child: MyApp(isFirstRun: isFirstRun),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isFirstRun;
  const MyApp({super.key, required this.isFirstRun});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Movie Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000010),
        primaryColor: const Color(0xFF7E3FF2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7E3FF2),
          secondary: Color(0xFF00A2FF),
          surface: Color(0xFF151525),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ),
      home: isFirstRun ? const InitialSetupScreen() : const HomeScreen(),
    );
  }
}
