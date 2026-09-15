import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SoluTheme.applySystemChrome();

  final prefs = await SharedPreferences.getInstance();
  SoluStrings.lang = prefs.getString('solu_lang') ?? 'hi';
  final onboarded = prefs.getBool('solu_onboarded') ?? false;

  runApp(SoluApp(onboarded: onboarded));
}

class SoluApp extends StatelessWidget {
  const SoluApp({super.key, required this.onboarded});
  final bool onboarded;

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      child: MaterialApp(
        title: SoluConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: SoluTheme.dark(),
        home: SplashScreen(
          next: onboarded ? const ShellScreen() : const OnboardingScreen(),
        ),
      ),
    );
  }
}
