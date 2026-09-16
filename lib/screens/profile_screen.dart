import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/history_store.dart';
import 'diagnostics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    HistoryStore.load().then((l) {
      if (mounted) setState(() => _count = l.length);
    });
  }

  Future<void> _pickLanguage() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SoluStrings.languages.map((l) {
            final selected = SoluStrings.lang == l['code'];
            return ListTile(
              title: Text(l['native']!),
              subtitle: Text(l['label']!,
                  style: const TextStyle(color: SoluColors.textMuted)),
              trailing: selected
                  ? const Icon(Icons.check, color: SoluColors.brandAlt)
                  : null,
              onTap: () => Navigator.of(context).pop(l['code']),
            );
          }).toList(),
        ),
      ),
    );
    if (code == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solu_lang', code);
    LanguageScope.setLanguage(code);
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  gradient: SoluColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.black, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Solu user',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('$_count ${tr('videos')}',
                        style: const TextStyle(
                            fontSize: 13, color: SoluColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _tile(
            icon: Icons.translate,
            title: tr('language'),
            trailing: SoluStrings.languages
                .firstWhere((l) => l['code'] == SoluStrings.lang)['native'],
            onTap: _pickLanguage,
          ),
          _tile(
            icon: Icons.monitor_heart_outlined,
            title: 'Server check',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
            ),
          ),
          _tile(
            icon: Icons.privacy_tip_outlined,
            title: tr('privacy'),
            onTap: () => _open(SoluConfig.privacyUrl),
          ),
          _tile(
            icon: Icons.mail_outline,
            title: tr('support'),
            onTap: () => _open('mailto:${SoluConfig.supportEmail}'),
          ),
          _tile(
            icon: Icons.flag_outlined,
            title: 'Report content',
            onTap: () => _open(
                'mailto:${SoluConfig.supportEmail}?subject=Report%20content'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Image.asset('assets/brand/logo_full.png', width: 54),
                const SizedBox(height: 10),
                const Text('Solu AI v3.0.0',
                    style:
                        TextStyle(fontSize: 12, color: SoluColors.textMuted)),
                const SizedBox(height: 4),
                Text(
                  SoluConfig.isConfigured
                      ? 'Server connected'
                      : tr('not_configured'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: SoluConfig.isConfigured
                        ? SoluColors.success
                        : SoluColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: SoluColors.surface,
        borderRadius: BorderRadius.circular(SoluRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(SoluRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: SoluColors.brandAlt),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (trailing != null)
                  Text(trailing,
                      style: const TextStyle(
                          fontSize: 13, color: SoluColors.textMuted)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    size: 18, color: SoluColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
