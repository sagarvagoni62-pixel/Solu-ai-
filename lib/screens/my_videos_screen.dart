import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/scenes.dart';
import '../services/history_store.dart';
import '../widgets/common.dart';
import 'result_screen.dart';
import 'shell_screen.dart';

class MyVideosScreen extends StatefulWidget {
  const MyVideosScreen({super.key});

  @override
  State<MyVideosScreen> createState() => _MyVideosScreenState();
}

class _MyVideosScreenState extends State<MyVideosScreen> {
  List<HistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await HistoryStore.load();
    if (!mounted) return;
    setState(() {
      _items = list.where((i) => i.exists).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: SoluColors.brandAlt));
    }

    if (_items.isEmpty) {
      return SafeArea(
        child: EmptyState(
          icon: Icons.video_library_outlined,
          title: tr('no_videos'),
          subtitle: tr('no_videos_sub'),
          action: SizedBox(
            width: 200,
            child: GradientButton(
              label: tr('explore'),
              onTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const ShellScreen(initialIndex: 1)),
                (r) => false,
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        color: SoluColors.brandAlt,
        backgroundColor: SoluColors.surface,
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final item = _items[i];
            final scene = SceneCatalog.byId(item.sceneId);
            return Material(
              color: SoluColors.surface,
              borderRadius: BorderRadius.circular(SoluRadius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  if (scene == null) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ResultScreen(
                        scene: scene, file: File(item.filePath)),
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(SoluRadius.sm),
                        child: Image.asset(
                          SceneCatalog.posterFor(item.sceneId),
                          width: 64,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              _ago(item.createdAt),
                              style: const TextStyle(
                                  fontSize: 12, color: SoluColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20),
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(files: [XFile(item.filePath)]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: SoluColors.textMuted),
                        onPressed: () async {
                          await HistoryStore.remove(item.id);
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes} min pehle';
    if (d.inHours < 24) return '${d.inHours} ghante pehle';
    return '${d.inDays} din pehle';
  }
}
