import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/scenes.dart';
import '../widgets/pro_components.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'my_videos_screen.dart';
import 'profile_screen.dart';
import 'scene_detail_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late int _index = widget.initialIndex;

  void _create() {
    final scene = SceneCatalog.byId('swarg_darwaza') ?? SceneCatalog.all.first;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SceneDetailScreen(scene: scene)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomeScreen(),
      ExploreScreen(),
      MyVideosScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: FloatingNavBar(
        index: _index,
        onSelected: (i) => setState(() => _index = i),
        onCreate: _create,
        items: [
          NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: tr('home'),
          ),
          NavItem(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            label: tr('explore'),
          ),
          NavItem(
            icon: Icons.video_library_outlined,
            activeIcon: Icons.video_library_rounded,
            label: tr('videos'),
          ),
          NavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: tr('profile'),
          ),
        ],
      ),
    );
  }
}
