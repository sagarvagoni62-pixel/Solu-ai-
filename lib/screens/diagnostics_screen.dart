import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/solu_api.dart';
import '../core/theme.dart';

/// Developer-facing health check. Runs every hop of the pipeline and prints the
/// raw result so a single screenshot is enough to fix the backend.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _api = SoluApi();
  String _text = 'Checking...';
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _text = 'Checking...';
    });
    String out;
    try {
      out = await _api.selfTest();
    } catch (e) {
      out = 'self test crashed: $e';
    }
    if (!mounted) return;
    setState(() {
      _text = out;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoluColors.canvas,
      appBar: AppBar(
        title: const Text('Server check'),
        actions: [
          IconButton(
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(
            tooltip: 'Run again',
            onPressed: _busy ? null : _run,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SoluColors.surface,
              borderRadius: BorderRadius.circular(SoluRadius.md),
              border: Border.all(color: SoluColors.stroke),
            ),
            child: SelectableText(
              _text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.55,
                color: SoluColors.text,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'OK ka matlab wo hop sahi hai. FAIL wali line hi asli problem hai.',
            style: TextStyle(color: SoluColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
