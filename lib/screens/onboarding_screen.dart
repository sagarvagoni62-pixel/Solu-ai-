import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'shell_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;
  String _lang = SoluStrings.lang;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solu_lang', _lang);
    await prefs.setBool('solu_onboarded', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShellScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pager,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _languagePage(),
                  _infoPage(
                    image: 'assets/brand/onboarding_1.jpg',
                    title: tr('hero_title'),
                    body: tr('hero_sub'),
                  ),
                  _infoPage(
                    image: 'assets/posters/swarg.jpg',
                    title: tr('photo_tips'),
                    body:
                        '1. ${tr('tip_1')}\n2. ${tr('tip_2')}\n3. ${tr('tip_3')}',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final on = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: on ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: on ? SoluColors.brandAlt : SoluColors.raised,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  GradientButton(
                    label: _page == 2 ? tr('get_started') : tr('continue'),
                    onTap: () {
                      if (_page == 2) {
                        _finish();
                      } else {
                        _pager.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut);
                      }
                    },
                  ),
                  if (_page < 2)
                    TextButton(
                      onPressed: _finish,
                      child: Text(tr('skip'),
                          style: const TextStyle(color: SoluColors.textMuted)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languagePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/brand/logo_full.png', width: 72),
          const SizedBox(height: 28),
          Text(tr('choose_language'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          ...SoluStrings.languages.map((l) {
            final code = l['code']!;
            final selected = _lang == code;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: selected
                    ? SoluColors.brand.withValues(alpha: 0.14)
                    : SoluColors.surface,
                borderRadius: BorderRadius.circular(SoluRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(SoluRadius.md),
                  onTap: () {
                    setState(() => _lang = code);
                    LanguageScope.setLanguage(code);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SoluRadius.md),
                      border: Border.all(
                          color: selected
                              ? SoluColors.brand
                              : SoluColors.stroke),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l['native']!,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(l['label']!,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: SoluColors.textMuted)),
                            ],
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? SoluColors.brandAlt
                              : SoluColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _infoPage(
      {required String image, required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SoluRadius.xl),
              child: Image.asset(image, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 28),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14.5, color: SoluColors.textMuted, height: 1.5)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
