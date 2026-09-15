import 'package:flutter/material.dart';

import '../api/solu_api.dart';
import '../core/config.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/scenes.dart';
import '../widgets/common.dart';
import '../widgets/scene_card.dart';
import 'scene_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = SoluApi();
  List<Scene> _scenes = SceneCatalog.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _api.scenes();
    if (!mounted) return;
    setState(() {
      _scenes = list;
      _loading = false;
    });
  }

  void _open(Scene s) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SceneDetailScreen(scene: s)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured =
        _scenes.where((s) => s.featured).toList(growable: false);
    final hero = featured.isEmpty ? _scenes : featured;

    return RefreshIndicator(
      color: SoluColors.brandAlt,
      backgroundColor: SoluColors.surface,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: true,
            backgroundColor: SoluColors.canvas,
            title: Row(
              children: [
                Image.asset('assets/brand/logo_full.png', height: 30),
                const SizedBox(width: 10),
                const Text('Solu AI',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            actions: [
              if (!SoluConfig.isConfigured)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: tr('not_configured'),
                    child: const Icon(Icons.cloud_off,
                        color: SoluColors.error, size: 20),
                  ),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('hero_title'),
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(tr('hero_sub'),
                      style: const TextStyle(
                          fontSize: 14, color: SoluColors.textMuted, height: 1.45)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: SectionHeader(title: tr('featured'))),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 330,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20, right: 6),
                itemCount: hero.length,
                itemBuilder: (_, i) => SceneHeroCard(
                  scene: hero[i],
                  onTap: () => _open(hero[i]),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SectionHeader(title: tr('all_scenes'))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => SceneTile(
                  scene: _scenes[i],
                  onTap: () => _open(_scenes[i]),
                ),
                childCount: _scenes.length,
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: SoluColors.textMuted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
