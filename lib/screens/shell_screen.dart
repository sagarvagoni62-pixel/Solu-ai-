import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'my_videos_screen.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      HomeScreen(),
      ExploreScreen(),
      MyVideosScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: SoluColors.surface,
          border: Border(top: BorderSide(color: SoluColors.stroke)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: SoluColors.brand.withValues(alpha: 0.16),
              labelTextStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
            child: NavigationBar(
              height: 64,
              elevation: 0,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home, color: SoluColors.brandAlt),
                  label: tr('home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.explore_outlined),
                  selectedIcon:
                      const Icon(Icons.explore, color: SoluColors.brandAlt),
                  label: tr('explore'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.video_library_outlined),
                  selectedIcon: const Icon(Icons.video_library,
                      color: SoluColors.brandAlt),
                  label: tr('videos'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon:
                      const Icon(Icons.person, color: SoluColors.brandAlt),
                  label: tr('profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
