import 'package:flutter/material.dart';

import '../api/solu_api.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/scenes.dart';
import '../widgets/common.dart';
import '../widgets/scene_card.dart';
import 'scene_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _api = SoluApi();
  final _searchCtrl = TextEditingController();
  List<Scene> _all = SceneCatalog.all;
  String _category = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _api.scenes().then((list) {
      if (!mounted) return;
      setState(() => _all = list);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final out = <String>['All'];
    for (final s in _all) {
      if (!out.contains(s.category)) out.add(s.category);
    }
    return out;
  }

  List<Scene> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((s) {
      final catOk = _category == 'All' || s.category == _category;
      final qOk = q.isEmpty ||
          s.title.toLowerCase().contains(q) ||
          s.subtitle.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q);
      return catOk && qOk;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: '${tr('explore')}...',
                hintStyle: const TextStyle(color: SoluColors.textMuted),
                prefixIcon:
                    const Icon(Icons.search, color: SoluColors.textMuted),
                filled: true,
                fillColor: SoluColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SoluRadius.md),
                  borderSide: const BorderSide(color: SoluColors.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SoluRadius.md),
                  borderSide: const BorderSide(color: SoluColors.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SoluRadius.md),
                  borderSide: const BorderSide(color: SoluColors.brand),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                return SoluChip(
                  label: c,
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                );
              },
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    title: 'Kuch nahi mila',
                    subtitle: 'Doosra naam ya category try karein',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) => SceneTile(
                      scene: list[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SceneDetailScreen(scene: list[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
