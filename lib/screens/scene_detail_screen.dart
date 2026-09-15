import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/scenes.dart';
import '../widgets/common.dart';
import 'photo_upload_screen.dart';

class SceneDetailScreen extends StatelessWidget {
  const SceneDetailScreen({super.key, required this.scene});
  final Scene scene;

  Future<void> _continue(BuildContext context) async {
    if (scene.sensitive) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ConsentSheet(),
      );
      if (ok != true) return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PhotoUploadScreen(scene: scene)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 420,
            pinned: true,
            backgroundColor: SoluColors.canvas,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(scene.poster, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x99000000),
                          Colors.transparent,
                          Color(0xFF0B0A0F),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SoluChip(label: scene.category, icon: Icons.category_outlined),
                      SoluChip(
                          label: scene.durationLabel,
                          icon: Icons.timer_outlined),
                      SoluChip(
                        label: scene.needsTwoPhotos ? '2 photo' : '1 photo',
                        icon: Icons.photo_outlined,
                      ),
                      const SoluChip(label: '9:16 HD', icon: Icons.hd_outlined),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(scene.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(scene.subtitle,
                      style: const TextStyle(
                          fontSize: 15,
                          color: SoluColors.textMuted,
                          height: 1.5)),
                  const SizedBox(height: 28),
                  Text(tr('photo_tips'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _tip(Icons.face_outlined, tr('tip_1')),
                  _tip(Icons.light_mode_outlined, tr('tip_2')),
                  _tip(Icons.person_outline, tr('tip_3')),
                  if (scene.sensitive) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SoluColors.raised,
                        borderRadius: BorderRadius.circular(SoluRadius.sm),
                        border: Border.all(color: SoluColors.stroke),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.favorite_outline,
                              size: 18, color: SoluColors.brandAlt),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(tr('respect_note'),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: SoluColors.textMuted,
                                    height: 1.45)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: GradientButton(
            label: tr('use_scene'),
            icon: Icons.auto_awesome,
            onTap: () => _continue(context),
          ),
        ),
      ),
    );
  }

  Widget _tip(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 17, color: SoluColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, color: SoluColors.text)),
            ),
          ],
        ),
      );
}

class _ConsentSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SoluColors.brand.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.volunteer_activism_outlined,
                color: SoluColors.brandAlt),
          ),
          const SizedBox(height: 16),
          Text('Zaroori baat', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(tr('respect_note'),
              style: const TextStyle(
                  fontSize: 14, color: SoluColors.textMuted, height: 1.5)),
          const SizedBox(height: 20),
          GradientButton(
            label: tr('i_agree'),
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: SoluColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}
