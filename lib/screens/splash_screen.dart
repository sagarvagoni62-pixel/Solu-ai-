import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});
  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, __, ___) => widget.next,
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          const GlowBackdrop(size: 420, color: SoluColors.brand),
          FadeTransition(
            opacity: _c,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.86, end: 1).animate(
                CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/brand/logo_full.png', width: 132),
                  const SizedBox(height: 22),
                  const Text(
                    SoluConfig.appName,
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    SoluConfig.tagline,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 13, color: SoluColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 48,
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2.2, color: SoluColors.brandAlt),
            ),
          ),
        ],
      ),
    );
  }
}
