import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/scenes.dart';
import '../widgets/common.dart';
import 'shell_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.scene, required this.file});
  final Scene scene;
  final File file;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  VideoPlayerController? _vc;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.file(widget.file);
    _vc = c;
    c.initialize().then((_) {
      if (!mounted) return;
      c
        ..setLooping(true)
        ..play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.file.path)],
        text: '${widget.scene.title} - Solu AI se banaya',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vc = _vc;
    final ready = vc != null && vc.value.isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('done')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ShellScreen()),
            (r) => false,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ready
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(SoluRadius.lg),
                      child: AspectRatio(
                        aspectRatio: vc.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(vc),
                            _PlayToggle(controller: vc),
                          ],
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(
                      color: SoluColors.brandAlt),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const ShellScreen(initialIndex: 2)),
                      (r) => false,
                    ),
                    icon: const Icon(Icons.video_library_outlined, size: 18),
                    label: Text(tr('videos')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: SoluColors.stroke),
                      foregroundColor: SoluColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: tr('share'),
                    icon: Icons.share,
                    height: 50,
                    onTap: _share,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(tr('again')),
                style: TextButton.styleFrom(
                    foregroundColor: SoluColors.textMuted,
                    minimumSize: const Size.fromHeight(44)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayToggle extends StatefulWidget {
  const _PlayToggle({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_PlayToggle> createState() => _PlayToggleState();
}

class _PlayToggleState extends State<_PlayToggle> {
  @override
  Widget build(BuildContext context) {
    final playing = widget.controller.value.isPlaying;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playing ? widget.controller.pause() : widget.controller.play();
        setState(() {});
      },
      child: AnimatedOpacity(
        opacity: playing ? 0 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0x99000000),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, size: 34),
        ),
      ),
    );
  }
}
