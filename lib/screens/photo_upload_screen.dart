import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/scenes.dart';
import '../widgets/common.dart';
import 'generating_screen.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key, required this.scene});
  final Scene scene;

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final _picker = ImagePicker();
  File? _photo1;
  File? _photo2;

  bool get _ready =>
      _photo1 != null && (!widget.scene.needsTwoPhotos || _photo2 != null);

  Future<void> _pick({required bool second}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: SoluColors.brandAlt),
              title: Text(tr('gallery')),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: SoluColors.brandAlt),
              title: Text(tr('camera')),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: SoluConfig.maxPhotoEdge.toDouble(),
      maxHeight: SoluConfig.maxPhotoEdge.toDouble(),
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (second) {
        _photo2 = File(picked.path);
      } else {
        _photo1 = File(picked.path);
      }
    });
  }

  void _start() {
    if (!SoluConfig.isConfigured) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('not_configured'))));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GeneratingScreen(
        scene: widget.scene,
        photo: _photo1!,
        photo2: _photo2,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scene;
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(tr('add_photo'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            s.needsTwoPhotos ? tr('needs_two') : tr('tip_1'),
            style: const TextStyle(color: SoluColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _slot(file: _photo1, label: tr('add_photo'), onTap: () => _pick(second: false)),
          if (s.needsTwoPhotos) ...[
            const SizedBox(height: 14),
            _slot(
                file: _photo2,
                label: tr('second_photo'),
                onTap: () => _pick(second: true)),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SoluColors.surface,
              borderRadius: BorderRadius.circular(SoluRadius.md),
              border: Border.all(color: SoluColors.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        size: 18, color: SoluColors.brandAlt),
                    const SizedBox(width: 8),
                    Text(tr('photo_tips'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                _tip(tr('tip_1')),
                _tip(tr('tip_2')),
                _tip(tr('tip_3')),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: GradientButton(
            label: tr('generate'),
            icon: Icons.movie_creation_outlined,
            onTap: _ready ? _start : null,
          ),
        ),
      ),
    );
  }

  Widget _slot({File? file, required String label, required VoidCallback onTap}) {
    return Material(
      color: SoluColors.surface,
      borderRadius: BorderRadius.circular(SoluRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: file == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SoluRadius.lg),
                    border: Border.all(color: SoluColors.stroke),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          gradient: SoluColors.brandGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_a_photo_outlined,
                            color: Colors.black),
                      ),
                      const SizedBox(height: 14),
                      Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('JPG / PNG',
                          style: TextStyle(
                              fontSize: 12, color: SoluColors.textMuted)),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file, fit: BoxFit.cover),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Material(
                        color: const Color(0xCC000000),
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: onTap,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tip(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 15, color: SoluColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t,
                  style: const TextStyle(
                      fontSize: 13, color: SoluColors.textMuted)),
            ),
          ],
        ),
      );
}
