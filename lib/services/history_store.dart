import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  final String id;
  final String sceneId;
  final String title;
  final String filePath;
  final String remoteUrl;
  final DateTime createdAt;

  const HistoryItem({
    required this.id,
    required this.sceneId,
    required this.title,
    required this.filePath,
    required this.remoteUrl,
    required this.createdAt,
  });

  bool get exists => File(filePath).existsSync();

  Map<String, dynamic> toJson() => {
        'id': id,
        'sceneId': sceneId,
        'title': title,
        'filePath': filePath,
        'remoteUrl': remoteUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: (j['id'] as String?) ?? '',
        sceneId: (j['sceneId'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        filePath: (j['filePath'] as String?) ?? '',
        remoteUrl: (j['remoteUrl'] as String?) ?? '',
        createdAt:
            DateTime.tryParse((j['createdAt'] as String?) ?? '') ?? DateTime.now(),
      );
}

/// Local-only history. Output URLs expire, so the mp4 is stored on device.
class HistoryStore {
  static const _key = 'solu_history_v2';

  static Future<List<HistoryItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(HistoryItem item) async {
    final items = await load();
    items.insert(0, item);
    await _save(items);
  }

  static Future<void> remove(String id) async {
    final items = await load();
    final keep = <HistoryItem>[];
    for (final i in items) {
      if (i.id == id) {
        try {
          final f = File(i.filePath);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      } else {
        keep.add(i);
      }
    }
    await _save(keep);
  }

  static Future<void> _save(List<HistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
