import 'package:flutter/material.dart';

import '../api/solu_api.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../data/scenes.dart';
import '../widgets/pro_components.dart';
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
  int _chip = 0;

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

  List<String> get _chipLabels {
    final cats = <String>{for (final s in _scenes) s.category};
    return ['All', 'New', ...cats];
  }

  List<Scene> get _filtered {
    final label = _chipLabels[_chip.clamp(0, _chipLabels.length - 1)];
    if (label == 'All') return _scenes;
    if (label == 'New') {
      return _scenes.where((s) => s.featured).toList(growable: false);
    }
    return _scenes.where((s) => s.category == label).toList(growable: false);
  }

  Map<String, int> get _chipCounts => {
        'New': _scenes.where((s) => s.featured).length,
        for (final label in _chipLabels.skip(2))
          label: _scenes.where((s) => s.category == label).length,
      };

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final hero = _scenes.where((s) => s.featured).take(3).toList();

    return RefreshIndicator(
      color: SoluColors.brandAlt,
      backgroundColor: SoluColors.surface,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: SoluColors.canvas,
            titleSpacing: 20,
            title: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    gradient: SoluColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome,
                      size: 16, color: Colors.black),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Solu AI',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            actions: [
              if (!SoluConfig.isConfigured)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.cloud_off,
                      color: SoluColors.error, size: 19),
                ),
              const UpgradePill(),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: ProChipBar(
              labels: _chipLabels,
              counts: _chipCounts,
              selected: _chip,
              onSelected: (i) => setState(() => _chip = i),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          SliverToBoxAdapter(
            child: PromoCarousel(
              slides: [
                PromoSlide(
                  title: 'Swarg Templates',
                  subtitle: 'Ek photo se 10 sec ki divine video',
                  cta: 'Try Style',
                  colors: const [Color(0xFFFF7A29), Color(0xFFFFC24B)],
                  poster: 'assets/posters/swarg.jpg',
                  onTap: hero.isEmpty ? null : () => _open(hero.first),
                ),
                PromoSlide(
                  title: 'Ashirwad Series',
                  subtitle: 'Apne bade-buzurgon ka pyara ashirwad',
                  cta: 'Try Style',
                  colors: const [Color(0xFF8B5CF6), Color(0xFFFF7A29)],
                  poster: 'assets/posters/ganpati.jpg',
                  onTap: hero.length < 2 ? null : () => _open(hero[1]),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: ProSectionHeader(
              title: 'Swarg & Shraddhanjali',
              onAction: () => setState(() => _chip = 0),
            ),
          ),
          SliverToBoxAdapter(
            child: MasonryGrid(
              children: [
                for (var i = 0; i < list.length; i++)
                  TemplateCard(
                    title: list[i].title,
                    poster: list[i].poster,
                    height: i.isEven ? 220 : 178,
                    pro: list[i].featured,
                    badge: list[i].durationLabel,
                    likes: '${12 + i * 3}.${(i * 4) % 10}k',
                    onTap: () => _open(list[i]),
                  ),
              ],
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 20),
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
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
