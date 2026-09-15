import 'dart:io';

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/scenes.dart';
import '../services/generation_controller.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

class GeneratingScreen extends StatefulWidget {
  const GeneratingScreen({
    super.key,
    required this.scene,
    required this.photo,
    this.photo2,
  });

  final Scene scene;
  final File photo;
  final File? photo2;

  @override
  State<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<GeneratingScreen> {
  final _ctrl = GenerationController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
    _run();
  }

  void _run() {
    _ctrl.start(
      scene: widget.scene,
      photo: widget.photo,
      photo2: widget.photo2,
    );
  }

  void _onChange() {
    if (!mounted) return;
    if (_ctrl.stage == GenStage.done && _ctrl.videoFile != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(
          scene: widget.scene,
          file: _ctrl.videoFile!,
        ),
      ));
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    if (!_ctrl.isBusy) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: SoluColors.surface,
        title: const Text('Cancel karein?'),
        content: const Text(
            'Video ban rahi hai. Peeche jaane se generation ruk jayegi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nahi'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Haan, cancel'),
          ),
        ],
      ),
    );
    if (leave == true) await _ctrl.cancel();
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final error = _ctrl.stage == GenStage.error;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      if (await _confirmExit() && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
                const Spacer(),
                if (error)
                  Column(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 56, color: SoluColors.error),
                      const SizedBox(height: 18),
                      Text(_ctrl.errorMessage ?? tr('error_generic'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, height: 1.5)),
                    ],
                  )
                else ...[
                  ProgressRing(value: _ctrl.progress),
                  const SizedBox(height: 30),
                  Text(tr('generating'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    _ctrl.label.isEmpty ? tr('please_wait') : _ctrl.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: SoluColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _steps(),
                ],
                const Spacer(),
                if (error)
                  GradientButton(
                    label: tr('retry'),
                    icon: Icons.refresh,
                    onTap: _run,
                  )
                else
                  Text(tr('please_wait'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, color: SoluColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _steps() {
    final stages = <GenStage, String>{
      GenStage.uploading: 'Photo upload',
      GenStage.queued: 'Queue',
      GenStage.rendering: 'Render',
      GenStage.saving: 'Save',
    };
    final order = stages.keys.toList();
    final current = order.indexOf(_ctrl.stage);

    return Column(
      children: List.generate(order.length, (i) {
        final done = current > i;
        final active = current == i;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle
                    : active
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                size: 17,
                color: done
                    ? SoluColors.success
                    : active
                        ? SoluColors.brandAlt
                        : SoluColors.textMuted,
              ),
              const SizedBox(width: 10),
              Text(
                stages[order[i]]!,
                style: TextStyle(
                  fontSize: 13.5,
                  color: done || active
                      ? SoluColors.text
                      : SoluColors.textMuted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
